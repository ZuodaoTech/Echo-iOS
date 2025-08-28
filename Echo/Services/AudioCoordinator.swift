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
    @Published var voiceActivityLevel: Float = 0  // Voice activity visualization (0.0 to 1.0)
    @Published var processingProgress: Double = 0  // Progress for long operations (0.0 to 1.0)
    @Published var processingMessage: String = ""  // Current processing step description
    
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
    
    // Private mode
    @Published var privateModeActive = false
    
    // Audio session state (for debugging)
    var audioSessionState: String {
        sessionManager.currentState.rawValue
    }
    
    // MARK: - Services (Lazy initialization for performance)
    
    private lazy var fileManager: AudioFileManager = AudioFileManager()
    private lazy var sessionManager: AudioSessionManager = AudioSessionManager()
    private lazy var recordingService: RecordingService = RecordingService(
        fileManager: self.fileManager,
        sessionManager: self.sessionManager
    )
    private lazy var playbackService: PlaybackService = PlaybackService(
        fileManager: self.fileManager,
        sessionManager: self.sessionManager
    )
    private lazy var processingService: AudioProcessingService = AudioProcessingService(
        fileManager: self.fileManager
    )
    
    // MARK: - Private Properties
    
    private var currentRecordingScript: SelftalkScript?
    private var cancellables = Set<AnyCancellable>()
    private var hasInitialized = false
    
    // MARK: - Initialization
    
    private init() {
        // Services are now lazy-initialized, nothing to do here
        // Property binding is also deferred to first actual use
    }
    
    private func ensureInitialized() {
        guard !hasInitialized else { return }
        hasInitialized = true
        bindPublishedProperties()
    }
    
    // MARK: - Recording Methods
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        ensureInitialized()
        sessionManager.requestMicrophonePermission(completion: completion)
    }
    
    func startRecording(for script: SelftalkScript) throws {
        ensureInitialized()
        // Stop any playback first and ensure clean state
        if isPlaying || isPaused || isInPlaybackSession {
            stopPlayback()
        }
        
        // If audio session is in transitioning state, force it to idle
        // This handles the case where stopPlayback was called but state hasn't settled
        if sessionManager.currentState == .transitioning {
            sessionManager.transitionTo(.idle)
        }
        
        try recordingService.startRecording(for: script.id)
        
        // Update script with audio file path and track current script
        script.audioFilePath = fileManager.audioURL(for: script.id).path
        // Clear old transcript when starting new recording
        script.transcribedText = nil
        DispatchQueue.main.async { [weak self] in
            self?.currentRecordingScript = script
        }
    }
    
    func stopRecording() {
        guard let script = currentRecordingScript else { 
            _ = recordingService.stopRecording() // Legacy call
            return 
        }
        
        // Show processing state
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isProcessingRecording = true
            self.processingScriptIds.insert(script.id)
            self.processingProgress = 0.1
            self.processingMessage = NSLocalizedString("processing.stopping_recording", comment: "Stopping recording...")
        }
        
        // Use async version to ensure file is ready
        recordingService.stopRecording { [weak self] scriptId, duration in
            guard let self = self else { return }
            
            // Update progress
            DispatchQueue.main.async { [weak self] in
                self?.processingProgress = 0.3
                self?.processingMessage = NSLocalizedString("processing.trimming_silence", comment: "Trimming silence...")
            }
            
            // Get voice activity timestamps from recording service
            let trimTimestamps = self.recordingService.getTrimTimestamps()
            
            // Process the recording (trim silence, etc.)
            self.processingService.processRecording(for: scriptId, trimTimestamps: trimTimestamps) { success in
                // Update progress
                DispatchQueue.main.async { [weak self] in
                    self?.processingProgress = 0.6
                    self?.processingMessage = NSLocalizedString("processing.transcribing", comment: "Transcribing audio...")
                }
                
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
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            self.currentRecordingScript = nil
                            self.isProcessingRecording = false
                            self.processingScriptIds.remove(scriptId)
                            self.processingProgress = 0
                            self.processingMessage = ""
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Playback Methods
    
    func play(script: SelftalkScript) throws {
        ensureInitialized()
        print("\n🎤 AudioCoordinator.play() called for script \(script.id)")
        
        // DEFENSIVE: Check script validity
        guard !script.isDeleted,
              !script.isFault,
              script.managedObjectContext != nil else {
            print("   ❌ Invalid script (deleted/fault/no context)")
            throw AudioServiceError.invalidScript
        }
        
        // Stop any recording first
        if isRecording {
            print("   🔴 Stopping active recording first")
            stopRecording()
        }
        
        // Note: PlaybackService will auto-stop any current playback
        // This ensures only one script plays at a time
        try playbackService.startPlayback(
            scriptId: script.id,
            repetitions: Int(script.repetitions),
            intervalSeconds: script.intervalSeconds,
            privateModeEnabled: script.privateModeEnabled
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
    
    func checkPrivateMode() {
        sessionManager.checkPrivateMode()
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
        
        recordingService.$voiceActivityLevel
            .assign(to: &$voiceActivityLevel)
        
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
        sessionManager.$privateModeActive
            .assign(to: &$privateModeActive)
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