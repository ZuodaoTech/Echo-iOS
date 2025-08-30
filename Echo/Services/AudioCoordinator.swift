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
        ensureInitialized()
        guard let sessionManager = sessionManager else {
            return "unavailable"
        }
        return sessionManager.currentState.rawValue
    }
    
    // MARK: - Services (Lazy initialization for performance)
    
    private var fileManager: AudioFileManager?
    private var sessionManager: AudioSessionManager?
    private var recordingService: RecordingService?
    private var playbackService: PlaybackService?
    private var processingService: AudioProcessingService?
    
    // MARK: - Private Properties
    
    private var currentRecordingScript: SelftalkScript?
    private var cancellables = Set<AnyCancellable>()
    private var hasInitializedServices = false // Track service initialization
    
    // MARK: - Initialization
    
    private init() {
        // Services are now lazy-initialized, nothing to do here
        // Property binding is also deferred to first actual use
    }
    
    private func ensureInitialized() {
        guard !hasInitializedServices else { return }
        hasInitializedServices = true

        createServices()
        bindPublishedProperties()
    }
    
    // MARK: - Service Availability Monitoring
    
    /// Computed property to check if all services are ready for use
    var isServicesReady: Bool {
        return fileManager != nil &&
               sessionManager != nil &&
               recordingService != nil &&
               playbackService != nil &&
               processingService != nil
    }
    
    /// Individual service availability checks
    var isFileManagerReady: Bool { fileManager != nil }
    var isSessionManagerReady: Bool { sessionManager != nil }
    var isRecordingServiceReady: Bool { recordingService != nil }
    var isPlaybackServiceReady: Bool { playbackService != nil }
    var isProcessingServiceReady: Bool { processingService != nil }
    
    /// Provides feedback message when services are unavailable
    var serviceUnavailableMessage: String? {
        if !isServicesReady {
            var missing: [String] = []
            if !isFileManagerReady { missing.append("FileManager") }
            if !isSessionManagerReady { missing.append("SessionManager") }
            if !isRecordingServiceReady { missing.append("RecordingService") }
            if !isPlaybackServiceReady { missing.append("PlaybackService") }
            if !isProcessingServiceReady { missing.append("ProcessingService") }
            return "Audio services unavailable: \(missing.joined(separator: ", "))"
        }
        return nil
    }
    
    private func ensureServicesAvailable() -> Bool {
        ensureInitialized()
        return isServicesReady
    }
    // MARK: - Private Methods
    
    private func createServices() {
        do {
            // Initialize core services first
            let tempFileManager = AudioFileManager()
            let tempSessionManager = AudioSessionManager()
            
            // Initialize dependent services
            let tempRecordingService = RecordingService(fileManager: tempFileManager, sessionManager: tempSessionManager)
            let tempPlaybackService = PlaybackService(fileManager: tempFileManager, sessionManager: tempSessionManager)
            let tempProcessingService = AudioProcessingService(fileManager: tempFileManager)
            
            // Only assign if all services created successfully
            self.fileManager = tempFileManager
            self.sessionManager = tempSessionManager
            self.recordingService = tempRecordingService
            self.playbackService = tempPlaybackService
            self.processingService = tempProcessingService
            
            SecureLogger.info("AudioCoordinator services initialized successfully")
        } catch {
            SecureLogger.error("Critical: Failed to initialize AudioCoordinator services: \(error.localizedDescription)")
            // Leave services as nil - app will gracefully handle unavailable services
            // This prevents crashes and allows the app to continue functioning with limited capabilities
        }
    }


    // MARK: - Recording Methods
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        ensureInitialized()
        guard let sessionManager = sessionManager else {
            SecureLogger.error("SessionManager unavailable for microphone permission request")
            completion(false)
            return
        }
        sessionManager.requestMicrophonePermission(completion: completion)
    }
    
    func startRecording(for script: SelftalkScript) throws {
        ensureInitialized()
        
        // Ensure all required services are available
        guard let sessionManager = sessionManager else {
            SecureLogger.error("SessionManager unavailable for recording")
            throw AudioServiceError.serviceUnavailable
        }
        
        guard let recordingService = recordingService else {
            SecureLogger.error("RecordingService unavailable for recording")
            throw AudioServiceError.serviceUnavailable
        }
        
        guard let fileManager = fileManager else {
            SecureLogger.error("FileManager unavailable for recording")
            throw AudioServiceError.serviceUnavailable
        }
        
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
            // Legacy call with safe unwrapping
            if let recordingService = recordingService {
                _ = recordingService.stopRecording()
            }
            return 
        }
        
        // Ensure required services are available
        guard let recordingService = recordingService,
              let processingService = processingService,
              let fileManager = fileManager else {
            SecureLogger.error("Required services unavailable for stopping recording")
            DispatchQueue.main.async { [weak self] in
                self?.currentRecordingScript = nil
                self?.isProcessingRecording = false
                if let scriptId = script.id as UUID? {
                    self?.processingScriptIds.remove(scriptId)
                }
                self?.processingProgress = 0
                self?.processingMessage = ""
            }
            return
        }
        
        // Mark that user has recorded before (for optimizations)
        UserDefaults.standard.set(true, forKey: "hasRecordedBefore")
        
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
            guard let recordingService = self.recordingService,
                  let processingService = self.processingService else {
                SecureLogger.error("Services unavailable during recording processing")
                DispatchQueue.main.async { [weak self] in
                    self?.currentRecordingScript = nil
                    self?.isProcessingRecording = false
                    self?.processingScriptIds.remove(scriptId)
                    self?.processingProgress = 0
                    self?.processingMessage = ""
                }
                return
            }
            
            let trimTimestamps = recordingService.getTrimTimestamps()
            
            // Process the recording (trim silence, etc.)
            processingService.processRecording(for: scriptId, trimTimestamps: trimTimestamps) { success in
                // Update progress
                DispatchQueue.main.async { [weak self] in
                    self?.processingProgress = 0.6
                    self?.processingMessage = NSLocalizedString("processing.transcribing", comment: "Transcribing audio...")
                }
                
                // After processing, transcribe the ORIGINAL audio with selected language
                // The original audio maintains AAC format that Speech Recognition can read
                let languageCode = script.transcriptionLanguage ?? "en-US"
                #if DEBUG
                SecureLogger.debug("Starting transcription with language")
                #endif
                
                // Safely access processing service for transcription
                guard let processingService = self.processingService,
                      let fileManager = self.fileManager else {
                    SecureLogger.error("Services unavailable for transcription")
                    DispatchQueue.main.async { [weak self] in
                        self?.currentRecordingScript = nil
                        self?.isProcessingRecording = false
                        self?.processingScriptIds.remove(scriptId)
                        self?.processingProgress = 0
                        self?.processingMessage = ""
                    }
                    return
                }
                
                processingService.transcribeRecording(for: scriptId, languageCode: languageCode) { transcription in
                    DispatchQueue.main.async {
                        // Get actual duration from file after processing
                        if let fileDuration = fileManager.getAudioDuration(for: scriptId) {
                            script.audioDuration = fileDuration
                            #if DEBUG
                            SecureLogger.debug("Recording processed - Duration: \(String(format: "%.2f", fileDuration))s, Success: \(success)")
                            #endif
                        } else {
                            // Fallback to recorder's duration
                            script.audioDuration = duration
                            #if DEBUG
                            SecureLogger.debug("Recording completed - Using recorder duration: \(String(format: "%.2f", duration))s")
                            #endif
                        }
                        
                        // Save transcription if available
                        if let transcription = transcription {
                            script.transcribedText = transcription
                            #if DEBUG
                            SecureLogger.debug("Transcription saved successfully")
                            #endif
                            // Force Core Data save
                            do {
                                try script.managedObjectContext?.save()
                                #if DEBUG
                                SecureLogger.debug("Core Data saved with transcript")
                                #endif
                            } catch {
                                SecureLogger.error("Failed to save transcript to Core Data: \(error.localizedDescription)")
                            }
                        } else {
                            SecureLogger.warning("No transcription received")
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
        #if DEBUG
        SecureLogger.debug("AudioCoordinator.play() called for script")
        #endif
        
        // DEFENSIVE: Check script validity
        guard !script.isDeleted,
              !script.isFault,
              script.managedObjectContext != nil else {
            SecureLogger.error("Invalid script (deleted/fault/no context)")
            throw AudioServiceError.invalidScript
        }
        
        // Ensure playback service is available
        guard let playbackService = playbackService else {
            SecureLogger.error("PlaybackService unavailable for playback")
            throw AudioServiceError.serviceUnavailable
        }
        
        // Stop any recording first
        if isRecording {
            #if DEBUG
            SecureLogger.debug("Stopping active recording first")
            #endif
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
        ensureInitialized()
        guard let playbackService = playbackService else {
            SecureLogger.error("PlaybackService unavailable for pause")
            return
        }
        playbackService.pausePlayback()
    }
    
    func resumePlayback() {
        ensureInitialized()
        guard let playbackService = playbackService else {
            SecureLogger.error("PlaybackService unavailable for resume")
            return
        }
        playbackService.resumePlayback()
    }
    
    func stopPlayback() {
        ensureInitialized()
        guard let playbackService = playbackService else {
            SecureLogger.error("PlaybackService unavailable for stop")
            return
        }
        playbackService.stopPlayback()
    }
    
    func setPlaybackSpeed(_ speed: Float) {
        ensureInitialized()
        guard let playbackService = playbackService else {
            SecureLogger.error("PlaybackService unavailable for speed adjustment")
            return
        }
        playbackService.setPlaybackSpeed(speed)
    }
    
    // MARK: - File Management Methods
    
    func deleteRecording(for script: SelftalkScript) {
        ensureInitialized()
        
        // Stop playback if playing this script
        if currentPlayingScriptId == script.id {
            stopPlayback()
        }
        
        // Delete the file with safe unwrapping
        if let fileManager = fileManager {
            try? fileManager.deleteRecording(for: script.id)
        } else {
            SecureLogger.error("FileManager unavailable for deleting recording")
        }
        
        // Clear script properties including transcript
        script.audioFilePath = nil
        script.audioDuration = 0
        script.transcribedText = nil  // Clear transcript when audio is deleted
    }
    
    func checkPrivateMode() {
        ensureInitialized()
        guard let sessionManager = sessionManager else {
            SecureLogger.error("SessionManager unavailable for private mode check")
            return
        }
        sessionManager.checkPrivateMode()
    }
    
    // MARK: - Private Methods
    
    private func bindPublishedProperties() {
        // Bind recording properties with safe unwrapping
        recordingService?.$isRecording
            .assign(to: &$isRecording)
        
        recordingService?.$recordingDuration
            .assign(to: &$recordingDuration)
        
        recordingService?.$isProcessing
            .assign(to: &$isProcessingRecording)
        
        recordingService?.$voiceActivityLevel
            .assign(to: &$voiceActivityLevel)
        
        // Bind playback properties with safe unwrapping
        playbackService?.$isPlaying
            .assign(to: &$isPlaying)
        
        playbackService?.$isPaused
            .assign(to: &$isPaused)
        
        playbackService?.$isInPlaybackSession
            .assign(to: &$isInPlaybackSession)
        
        playbackService?.$currentPlayingScriptId
            .assign(to: &$currentPlayingScriptId)
        
        playbackService?.$playbackProgress
            .assign(to: &$playbackProgress)
        
        playbackService?.$currentRepetition
            .assign(to: &$currentRepetition)
        
        playbackService?.$totalRepetitions
            .assign(to: &$totalRepetitions)
        
        playbackService?.$isInInterval
            .assign(to: &$isInInterval)
        
        playbackService?.$intervalProgress
            .assign(to: &$intervalProgress)
        
        // Bind session manager properties with safe unwrapping
        sessionManager?.$privateModeActive
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
        guard let fileManager = fileManager else {
            SecureLogger.error("FileManager unavailable for audio file check")
            return false
        }
        return fileManager.audioFileExists(for: script.id)
    }
    
    /// Get audio duration for a script (for backward compatibility)
    func getAudioDuration(for script: SelftalkScript) -> TimeInterval? {
        guard let fileManager = fileManager else {
            SecureLogger.error("FileManager unavailable for audio duration check")
            return nil
        }
        return fileManager.getAudioDuration(for: script.id)
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
