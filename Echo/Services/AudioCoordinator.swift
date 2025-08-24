import Foundation
import Combine
import SwiftUI

/// Coordinates all audio services and provides a unified interface
/// This replaces the old AudioService singleton
final class AudioCoordinator: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AudioCoordinator()
    
    // MARK: - Published Properties (Combined from all services)
    
    // Recording state
    @Published var isRecording = false
    @Published var isProcessingRecording = false  // New: shows processing state
    @Published var recordingDuration: TimeInterval = 0
    @Published var processingScriptIds = Set<UUID>()  // Track which scripts are being processed
    
    // Playback state
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var isInPlaybackSession = false
    @Published var currentPlayingScriptId: UUID?
    @Published var playbackProgress: Double = 0
    @Published var currentRepetition: Int = 0
    @Published var totalRepetitions: Int = 0
    @Published var isInInterval = false
    @Published var intervalProgress: Double = 0
    
    // Privacy mode
    @Published var privacyModeActive = false
    
    // MARK: - Services
    
    private let fileManager: AudioFileManager
    private let sessionManager: AudioSessionManager
    private let recordingService: RecordingService
    private let playbackService: PlaybackService
    private let processingService: AudioProcessingService
    
    // MARK: - Private Properties
    
    private var currentRecordingScript: SelftalkScript?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        // Initialize services
        self.fileManager = AudioFileManager()
        self.sessionManager = AudioSessionManager()
        self.recordingService = RecordingService(
            fileManager: fileManager,
            sessionManager: sessionManager
        )
        self.playbackService = PlaybackService(
            fileManager: fileManager,
            sessionManager: sessionManager
        )
        self.processingService = AudioProcessingService(
            fileManager: fileManager
        )
        
        // Bind published properties
        bindPublishedProperties()
    }
    
    // MARK: - Recording Methods
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        sessionManager.requestMicrophonePermission(completion: completion)
    }
    
    func startRecording(for script: SelftalkScript) throws {
        // Stop any playback first
        stopPlayback()
        
        try recordingService.startRecording(for: script.id)
        
        // Update script with audio file path and track current script
        script.audioFilePath = fileManager.audioURL(for: script.id).path
        // Clear old transcript when starting new recording
        script.transcribedText = nil
        currentRecordingScript = script
    }
    
    func stopRecording() {
        guard let script = currentRecordingScript else { 
            _ = recordingService.stopRecording() // Legacy call
            return 
        }
        
        // Show processing state
        DispatchQueue.main.async {
            self.isProcessingRecording = true
            self.processingScriptIds.insert(script.id)
        }
        
        // Use async version to ensure file is ready
        recordingService.stopRecording { [weak self] scriptId, duration in
            guard let self = self else { return }
            
            // Process the recording (trim silence, etc.)
            self.processingService.processRecording(for: scriptId) { success in
                // After processing, transcribe the ORIGINAL audio with selected language
                // The original audio maintains AAC format that Speech Recognition can read
                let languageCode = script.transcriptionLanguage ?? "en-US"
                print("Starting transcription with language: \(languageCode)")
                self.processingService.transcribeRecording(for: scriptId, languageCode: languageCode) { transcription in
                    DispatchQueue.main.async {
                        // Get actual duration from file after processing
                        if let fileDuration = self.fileManager.getAudioDuration(for: scriptId) {
                            script.audioDuration = fileDuration
                            print("Recording processed - Duration: \(fileDuration)s, Success: \(success)")
                        } else {
                            // Fallback to recorder's duration
                            script.audioDuration = duration
                            print("Recording completed - Using recorder duration: \(duration)s")
                        }
                        
                        // Save transcription if available
                        if let transcription = transcription {
                            script.transcribedText = transcription
                            print("Transcription saved: \(transcription.prefix(50))...")
                            // Force Core Data save
                            do {
                                try script.managedObjectContext?.save()
                                print("Core Data saved with transcript")
                            } catch {
                                print("Failed to save transcript to Core Data: \(error)")
                            }
                        } else {
                            print("No transcription received")
                        }
                        
                        self.currentRecordingScript = nil
                        self.isProcessingRecording = false
                        self.processingScriptIds.remove(scriptId)
                    }
                }
            }
        }
    }
    
    // MARK: - Playback Methods
    
    func play(script: SelftalkScript) throws {
        // DEFENSIVE: Check script validity
        guard !script.isDeleted,
              !script.isFault,
              script.managedObjectContext != nil else {
            throw AudioServiceError.invalidScript
        }
        
        // Stop any recording first
        if isRecording {
            stopRecording()
        }
        
        try playbackService.startPlayback(
            scriptId: script.id,
            repetitions: Int(script.repetitions),
            intervalSeconds: script.intervalSeconds,
            privacyModeEnabled: script.privacyModeEnabled
        )
        
        // Increment play count
        script.incrementPlayCount()
    }
    
    func pausePlayback() {
        playbackService.pausePlayback()
    }
    
    func resumePlayback() {
        playbackService.resumePlayback()
    }
    
    func stopPlayback() {
        playbackService.stopPlayback()
    }
    
    func setPlaybackSpeed(_ speed: Float) {
        playbackService.setPlaybackSpeed(speed)
    }
    
    // MARK: - File Management Methods
    
    func deleteRecording(for script: SelftalkScript) {
        // Stop playback if playing this script
        if currentPlayingScriptId == script.id {
            stopPlayback()
        }
        
        // Delete the file
        try? fileManager.deleteRecording(for: script.id)
        
        // Clear script properties including transcript
        script.audioFilePath = nil
        script.audioDuration = 0
        script.transcribedText = nil  // Clear transcript when audio is deleted
    }
    
    func checkPrivacyMode() {
        sessionManager.checkPrivacyMode()
    }
    
    // MARK: - Private Methods
    
    private func bindPublishedProperties() {
        // Bind recording properties
        recordingService.$isRecording
            .assign(to: &$isRecording)
        
        recordingService.$recordingDuration
            .assign(to: &$recordingDuration)
        
        recordingService.$isProcessing
            .assign(to: &$isProcessingRecording)
        
        // Bind playback properties
        playbackService.$isPlaying
            .assign(to: &$isPlaying)
        
        playbackService.$isPaused
            .assign(to: &$isPaused)
        
        playbackService.$isInPlaybackSession
            .assign(to: &$isInPlaybackSession)
        
        playbackService.$currentPlayingScriptId
            .assign(to: &$currentPlayingScriptId)
        
        playbackService.$playbackProgress
            .assign(to: &$playbackProgress)
        
        playbackService.$currentRepetition
            .assign(to: &$currentRepetition)
        
        playbackService.$totalRepetitions
            .assign(to: &$totalRepetitions)
        
        playbackService.$isInInterval
            .assign(to: &$isInInterval)
        
        playbackService.$intervalProgress
            .assign(to: &$intervalProgress)
        
        // Bind session manager properties
        sessionManager.$privacyModeActive
            .assign(to: &$privacyModeActive)
    }
}

// MARK: - Compatibility Extension

// This extension provides backward compatibility with existing code
// that uses AudioService methods
extension AudioCoordinator {
    
    /// Legacy compatibility - maps to AudioCoordinator
    static var audioService: AudioCoordinator {
        AudioCoordinator.shared
    }
    
    /// Check if audio file exists for a script (for backward compatibility)
    func hasRecording(for script: SelftalkScript) -> Bool {
        fileManager.audioFileExists(for: script.id)
    }
    
    /// Get audio duration for a script (for backward compatibility)
    func getAudioDuration(for script: SelftalkScript) -> TimeInterval? {
        fileManager.getAudioDuration(for: script.id)
    }
    
    /// Check if a specific script is currently being processed
    func isProcessing(script: SelftalkScript) -> Bool {
        // DEFENSIVE: Check script validity before accessing properties
        guard !script.isDeleted,
              !script.isFault,
              script.managedObjectContext != nil else {
            return false
        }
        
        return processingScriptIds.contains(script.id)
    }
}