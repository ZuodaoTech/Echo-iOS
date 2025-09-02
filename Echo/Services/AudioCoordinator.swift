import Foundation
import Combine
import SwiftUI

/// Coordinates all audio services and provides a unified interface
/// This replaces the old AudioService singleton
final class AudioCoordinator: ObservableObject {
    
    // MARK: - Audio State Machine
    
    enum AudioState: String {
        case idle = "idle"
        case recording = "recording"
        case processingRecording = "processingRecording"
        case playing = "playing"
        case paused = "paused"
        case inInterval = "inInterval"
        
        var canRecord: Bool {
            switch self {
            case .idle: return true
            default: return false
            }
        }
        
        var canPlay: Bool {
            switch self {
            case .idle: return true
            default: return false
            }
        }
        
        var canPause: Bool {
            switch self {
            case .playing, .inInterval: return true
            default: return false
            }
        }
        
        var canResume: Bool {
            switch self {
            case .paused: return true
            default: return false
            }
        }
        
        var canStop: Bool {
            switch self {
            case .recording, .playing, .paused, .inInterval: return true
            default: return false
            }
        }
    }
    
    // MARK: - Singleton
    
    static let shared = AudioCoordinator()
    
    // MARK: - Published Properties (Single Source of Truth)
    
    // Core state machine
    @Published private(set) var currentState: AudioState = .idle
    
    // Recording state
    @Published private(set) var isRecording = false
    @Published private(set) var isProcessingRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var processingScriptIds = Set<UUID>()  // Track which scripts are being processed
    @Published var voiceActivityLevel: Float = 0  // Voice activity visualization (0.0 to 1.0)
    @Published var processingProgress: Double = 0  // Progress for long operations (0.0 to 1.0)
    @Published var processingMessage: String = ""  // Current processing step description
    
    // Playback state
    @Published private(set) var isPlaying = false
    @Published private(set) var isPaused = false
    @Published private(set) var isInPlaybackSession = false
    @Published var currentPlayingScriptId: UUID?
    @Published var playbackProgress: Double = 0
    @Published var currentRepetition: Int = 0
    @Published var totalRepetitions: Int = 0
    @Published private(set) var isInInterval = false
    @Published var intervalProgress: Double = 0
    
    // Private mode
    @Published var privateModeActive = false
    
    // Audio session state (for debugging)
    var audioSessionState: String {
        sessionManager.currentState.rawValue
    }
    
    // MARK: - Services (Lazy initialization for performance)
    
    private var fileManager: AudioFileManager!
    private var sessionManager: AudioSessionManager!
    private var recordingService: RecordingService!
    private var playbackService: PlaybackService!
    private var processingService: AudioProcessingService!
    
    // MARK: - Private Properties
    
    private var currentRecordingScript: SelftalkScript?
    private var cancellables = Set<AnyCancellable>()
    private var hasInitializedServices = false // Track service initialization
    private let stateQueue = DispatchQueue(label: "com.echo.audiostate", attributes: .concurrent)
    
    // MARK: - Initialization
    
    private init() {
        // Services are now lazy-initialized, nothing to do here
        // Property binding is also deferred to first actual use
    }
    
    // MARK: - State Management
    
    private func transitionTo(_ newState: AudioState) {
        stateQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let oldState = self.currentState
            
            // Validate transition
            switch (oldState, newState) {
            case (.idle, .recording),
                 (.idle, .playing),
                 (.recording, .processingRecording),
                 (.recording, .idle),
                 (.processingRecording, .idle),
                 (.playing, .paused),
                 (.playing, .inInterval),
                 (.playing, .idle),
                 (.paused, .playing),
                 (.paused, .idle),
                 (.inInterval, .playing),
                 (.inInterval, .paused),
                 (.inInterval, .idle):
                // Valid transitions
                break
            default:
                print("⚠️ Invalid state transition: \(oldState) -> \(newState)")
                return
            }
            
            print("🔄 Audio state transition: \(oldState) -> \(newState)")
            
            DispatchQueue.main.async {
                self.currentState = newState
                
                // Update derived states based on new state
                switch newState {
                case .idle:
                    self.isRecording = false
                    self.isProcessingRecording = false
                    self.isPlaying = false
                    self.isPaused = false
                    self.isInPlaybackSession = false
                    self.isInInterval = false
                    
                case .recording:
                    self.isRecording = true
                    self.isProcessingRecording = false
                    self.isPlaying = false
                    self.isPaused = false
                    self.isInPlaybackSession = false
                    self.isInInterval = false
                    
                case .processingRecording:
                    self.isRecording = false
                    self.isProcessingRecording = true
                    self.isPlaying = false
                    self.isPaused = false
                    self.isInPlaybackSession = false
                    self.isInInterval = false
                    
                case .playing:
                    self.isRecording = false
                    self.isProcessingRecording = false
                    self.isPlaying = true
                    self.isPaused = false
                    self.isInPlaybackSession = true
                    self.isInInterval = false
                    
                case .paused:
                    self.isRecording = false
                    self.isProcessingRecording = false
                    self.isPlaying = false
                    self.isPaused = true
                    self.isInPlaybackSession = true
                    self.isInInterval = false
                    
                case .inInterval:
                    self.isRecording = false
                    self.isProcessingRecording = false
                    self.isPlaying = false
                    self.isPaused = false
                    self.isInPlaybackSession = true
                    self.isInInterval = true
                }
            }
        }
    }
    
    private func ensureInitialized() {
        guard !hasInitializedServices else { return }
        hasInitializedServices = true

        createServices()
        bindPublishedProperties()
    }
    // MARK: - Private Methods
    
    private func createServices() {
        fileManager = AudioFileManager()
        sessionManager = AudioSessionManager()
        recordingService = RecordingService(fileManager: fileManager, sessionManager: sessionManager)
        playbackService = PlaybackService(fileManager: fileManager, sessionManager: sessionManager)
        processingService = AudioProcessingService(fileManager: fileManager)
    }


    // MARK: - Recording Methods
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        ensureInitialized()
        sessionManager.requestMicrophonePermission(completion: completion)
    }
    
    func startRecording(for script: SelftalkScript) throws {
        ensureInitialized()
        
        // Check if we can record in current state
        guard currentState.canRecord else {
            print("⚠️ Cannot start recording in state: \(currentState)")
            throw AudioServiceError.invalidState("Cannot record in \(currentState) state")
        }
        
        // Transition to recording state
        transitionTo(.recording)
        
        do {
            try recordingService.startRecording(for: script.id)
            
            // Update script with audio file path and track current script
            script.audioFilePath = fileManager.audioURL(for: script.id).path
            // Clear old transcript when starting new recording
            script.transcribedText = nil
            DispatchQueue.main.async { [weak self] in
                self?.currentRecordingScript = script
            }
        } catch {
            // If recording fails, transition back to idle
            transitionTo(.idle)
            throw error
        }
    }
    
    func stopRecording() {
        guard currentState == .recording else {
            print("⚠️ Not currently recording, state: \(currentState)")
            return
        }
        
        guard let script = currentRecordingScript else { 
            _ = recordingService.stopRecording() // Legacy call
            transitionTo(.idle)
            return 
        }
        
        // Transition to processing state
        transitionTo(.processingRecording)
        
        // Mark that user has recorded before (for optimizations)
        UserDefaults.standard.set(true, forKey: "hasRecordedBefore")
        
        // Show processing state
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
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
                            self.processingScriptIds.remove(scriptId)
                            self.processingProgress = 0
                            self.processingMessage = ""
                            // Transition back to idle after processing
                            self.transitionTo(.idle)
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
        
        // Check if we can play in current state
        guard currentState.canPlay else {
            print("⚠️ Cannot start playback in state: \(currentState)")
            throw AudioServiceError.invalidState("Cannot play in \(currentState) state")
        }
        
        // Transition to playing state
        transitionTo(.playing)
        
        do {
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
        } catch {
            // If playback fails, transition back to idle
            transitionTo(.idle)
            throw error
        }
    }
    
    func pausePlayback() {
        ensureInitialized()
        
        guard currentState.canPause else {
            print("⚠️ Cannot pause in state: \(currentState)")
            return
        }
        
        playbackService.pausePlayback()
        transitionTo(.paused)
    }
    
    func resumePlayback() {
        ensureInitialized()
        
        guard currentState.canResume else {
            print("⚠️ Cannot resume in state: \(currentState)")
            return
        }
        
        playbackService.resumePlayback()
        transitionTo(.playing)
    }
    
    func stopPlayback() {
        ensureInitialized()
        
        guard currentState.canStop else {
            print("⚠️ Cannot stop in state: \(currentState)")
            return
        }
        
        playbackService.stopPlayback()
        transitionTo(.idle)
    }
    
    func setPlaybackSpeed(_ speed: Float) {
        ensureInitialized()
        playbackService.setPlaybackSpeed(speed)
    }
    
    // MARK: - File Management Methods
    
    func deleteRecording(for script: SelftalkScript) {
        ensureInitialized()
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
        ensureInitialized()
        sessionManager.checkPrivateMode()
    }
    
    // MARK: - Private Methods
    
    private func bindPublishedProperties() {
        // Register recording service callbacks
        // Note: State transitions are now managed centrally, 
        // these callbacks only update auxiliary properties
        
        recordingService.onDurationUpdate = { [weak self] duration in
            DispatchQueue.main.async {
                self?.recordingDuration = duration
            }
        }
        
        recordingService.onVoiceActivityUpdate = { [weak self] level in
            DispatchQueue.main.async {
                self?.voiceActivityLevel = level
            }
        }
        
        // Register playback service callbacks
        playbackService.onCurrentScriptIdChange = { [weak self] scriptId in
            DispatchQueue.main.async {
                self?.currentPlayingScriptId = scriptId
            }
        }
        
        playbackService.onProgressUpdate = { [weak self] progress in
            DispatchQueue.main.async {
                self?.playbackProgress = progress
            }
        }
        
        playbackService.onRepetitionUpdate = { [weak self] current, total in
            DispatchQueue.main.async {
                self?.currentRepetition = current
                self?.totalRepetitions = total
            }
        }
        
        playbackService.onIntervalStateChange = { [weak self] inInterval in
            DispatchQueue.main.async {
                // When service reports interval state, transition appropriately
                if inInterval {
                    self?.transitionTo(.inInterval)
                } else if self?.currentState == .inInterval {
                    // If we were in interval and now not, go back to playing
                    self?.transitionTo(.playing)
                }
            }
        }
        
        playbackService.onIntervalProgressUpdate = { [weak self] progress in
            DispatchQueue.main.async {
                self?.intervalProgress = progress
            }
        }
        
        // Handle playback completion
        playbackService.onPlaybackSessionChange = { [weak self] inSession in
            DispatchQueue.main.async {
                // When session ends, transition to idle
                if !inSession && self?.currentState != .idle {
                    self?.transitionTo(.idle)
                }
            }
        }
        
        // Bind session manager properties (still uses Combine)
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
