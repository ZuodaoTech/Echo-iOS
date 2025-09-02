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
    
    // Thread-safe initialization
    private let initQueue = DispatchQueue(label: "com.echo.audio.init")
    private var servicesInitialized = false
    
    // Thread-safe state management
    private let stateQueue = DispatchQueue(label: "com.echo.audiostate") // Serial queue for state
    private var internalState: AudioState = .idle // Internal state managed on serial queue
    
    // MARK: - Initialization
    
    private init() {
        // Services are now lazy-initialized, nothing to do here
        // Property binding is also deferred to first actual use
        setupInterruptionHandling()
    }
    
    // MARK: - Interruption Handling
    
    private func setupInterruptionHandling() {
        // Listen for interruption notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruptionBegan),
            name: AudioSessionManager.interruptionBeganNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruptionEnded),
            name: AudioSessionManager.interruptionEndedNotification,
            object: nil
        )
    }
    
    @objc private func handleInterruptionBegan(_ notification: Notification) {
        guard let info = notification.userInfo else { return }
        
        let isPhoneCall = info["isPhoneCall"] as? Bool ?? false
        let currentStateSnapshot = stateQueue.sync { internalState }
        
        print("🔇 AudioCoordinator: Interruption began - PhoneCall: \(isPhoneCall), State: \(currentStateSnapshot)")
        
        // CRITICAL: Save recording immediately for privacy
        if currentStateSnapshot == .recording {
            // Save partial recording immediately
            if let script = currentRecordingScript {
                savePartialRecording(for: script, reason: isPhoneCall ? .phoneCall : .otherInterruption)
            }
            
            // Transition to a special interrupted state (we'll add this)
            transitionTo(.idle) // For now, go to idle
            
            // Show appropriate message to user
            DispatchQueue.main.async { [weak self] in
                if isPhoneCall {
                    self?.processingMessage = NSLocalizedString("interruption.phone_call", 
                                                                comment: "Paused for privacy 🤫")
                } else {
                    self?.processingMessage = NSLocalizedString("interruption.paused", 
                                                                comment: "Recording paused • Your progress is saved")
                }
            }
        }
    }
    
    @objc private func handleInterruptionEnded(_ notification: Notification) {
        guard let info = notification.userInfo else { return }
        
        let shouldResume = info["shouldResume"] as? Bool ?? false
        let duration = info["duration"] as? TimeInterval ?? 0
        let previousState = info["previousState"] as? AudioSessionManager.AudioSessionState
        
        print("🔊 AudioCoordinator: Interruption ended - Duration: \(duration)s, ShouldResume: \(shouldResume)")
        
        // Handle recovery based on duration and previous state
        if previousState == .recording && duration < 3.0 {
            // Short interruption - can auto-resume
            if shouldResume {
                attemptRecordingResume()
            }
        } else if duration < 10.0 {
            // Medium interruption - prompt user
            showRecoveryOptions()
        } else {
            // Long interruption - save and offer new recording
            completePartialRecording()
        }
    }
    
    private enum InterruptionReason {
        case phoneCall
        case otherInterruption
    }
    
    private func savePartialRecording(for script: SelftalkScript, reason: InterruptionReason) {
        // Stop recording but save what we have
        recordingService.stopRecording { [weak self] scriptId, duration in
            guard let self = self else { return }
            
            // Save the partial recording metadata
            script.audioDuration = duration
            script.audioFilePath = self.fileManager.audioURL(for: scriptId).path
            
            // Add interruption marker to the transcript if available
            let interruptionMarker = reason == .phoneCall ? 
                " [Recording interrupted by phone call]" : " [Recording interrupted]"
            
            if let existingTranscript = script.transcribedText {
                script.transcribedText = existingTranscript + interruptionMarker
            }
            
            // Save to Core Data
            do {
                try script.managedObjectContext?.save()
                print("✅ Partial recording saved successfully - Duration: \(duration)s")
            } catch {
                print("❌ Failed to save partial recording: \(error)")
            }
        }
    }
    
    private func attemptRecordingResume() {
        // Implementation for auto-resume
        print("Attempting to auto-resume recording...")
    }
    
    private func showRecoveryOptions() {
        // Implementation for showing recovery UI
        print("Showing recovery options to user...")
    }
    
    private func completePartialRecording() {
        // Implementation for completing partial recording
        print("Completing partial recording...")
    }
    
    // MARK: - State Management
    
    private func transitionTo(_ newState: AudioState) {
        // Use sync dispatch for atomic state validation and update
        let stateUpdate = stateQueue.sync { () -> StateUpdate? in
            let oldState = self.internalState
            
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
                // Valid transitions - update internal state
                self.internalState = newState
                print("🔄 Audio state transition: \(oldState) -> \(newState)")
                
                // Compute derived states atomically
                return computeStateUpdate(for: newState)
                
            default:
                print("⚠️ Invalid state transition: \(oldState) -> \(newState)")
                return nil
            }
        }
        
        // Apply state update on main thread if valid
        if let update = stateUpdate {
            DispatchQueue.main.async { [weak self] in
                self?.applyStateUpdate(update)
            }
        }
    }
    
    // Helper struct for atomic state updates
    private struct StateUpdate {
        let state: AudioState
        let isRecording: Bool
        let isProcessingRecording: Bool
        let isPlaying: Bool
        let isPaused: Bool
        let isInPlaybackSession: Bool
        let isInInterval: Bool
    }
    
    private func computeStateUpdate(for state: AudioState) -> StateUpdate {
        switch state {
        case .idle:
            return StateUpdate(state: state,
                             isRecording: false,
                             isProcessingRecording: false,
                             isPlaying: false,
                             isPaused: false,
                             isInPlaybackSession: false,
                             isInInterval: false)
            
        case .recording:
            return StateUpdate(state: state,
                             isRecording: true,
                             isProcessingRecording: false,
                             isPlaying: false,
                             isPaused: false,
                             isInPlaybackSession: false,
                             isInInterval: false)
            
        case .processingRecording:
            return StateUpdate(state: state,
                             isRecording: false,
                             isProcessingRecording: true,
                             isPlaying: false,
                             isPaused: false,
                             isInPlaybackSession: false,
                             isInInterval: false)
            
        case .playing:
            return StateUpdate(state: state,
                             isRecording: false,
                             isProcessingRecording: false,
                             isPlaying: true,
                             isPaused: false,
                             isInPlaybackSession: true,
                             isInInterval: false)
            
        case .paused:
            return StateUpdate(state: state,
                             isRecording: false,
                             isProcessingRecording: false,
                             isPlaying: false,
                             isPaused: true,
                             isInPlaybackSession: true,
                             isInInterval: false)
            
        case .inInterval:
            return StateUpdate(state: state,
                             isRecording: false,
                             isProcessingRecording: false,
                             isPlaying: false,
                             isPaused: false,
                             isInPlaybackSession: true,
                             isInInterval: true)
        }
    }
    
    private func applyStateUpdate(_ update: StateUpdate) {
        self.currentState = update.state
        self.isRecording = update.isRecording
        self.isProcessingRecording = update.isProcessingRecording
        self.isPlaying = update.isPlaying
        self.isPaused = update.isPaused
        self.isInPlaybackSession = update.isInPlaybackSession
        self.isInInterval = update.isInInterval
    }
    
    private func ensureInitialized() {
        initQueue.sync {
            guard !servicesInitialized else { return }
            servicesInitialized = true
            
            createServices()
            bindPublishedProperties()
        }
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
        
        // Check if we can record in current state (thread-safe)
        let canRecord = stateQueue.sync { internalState.canRecord }
        guard canRecord else {
            let state = stateQueue.sync { internalState }
            print("⚠️ Cannot start recording in state: \(state)")
            throw AudioServiceError.invalidState("Cannot record in \(state) state")
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
        let isRecordingNow = stateQueue.sync { internalState == .recording }
        guard isRecordingNow else {
            let state = stateQueue.sync { internalState }
            print("⚠️ Not currently recording, state: \(state)")
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
        
        // Check if we can play in current state (thread-safe)
        let canPlay = stateQueue.sync { internalState.canPlay }
        guard canPlay else {
            let state = stateQueue.sync { internalState }
            print("⚠️ Cannot start playback in state: \(state)")
            throw AudioServiceError.invalidState("Cannot play in \(state) state")
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
        
        let canPause = stateQueue.sync { internalState.canPause }
        guard canPause else {
            let state = stateQueue.sync { internalState }
            print("⚠️ Cannot pause in state: \(state)")
            return
        }
        
        playbackService.pausePlayback()
        transitionTo(.paused)
    }
    
    func resumePlayback() {
        ensureInitialized()
        
        let canResume = stateQueue.sync { internalState.canResume }
        guard canResume else {
            let state = stateQueue.sync { internalState }
            print("⚠️ Cannot resume in state: \(state)")
            return
        }
        
        playbackService.resumePlayback()
        transitionTo(.playing)
    }
    
    func stopPlayback() {
        ensureInitialized()
        
        let canStop = stateQueue.sync { internalState.canStop }
        guard canStop else {
            let state = stateQueue.sync { internalState }
            print("⚠️ Cannot stop in state: \(state)")
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
            guard let self = self else { return }
            // When service reports interval state, transition appropriately
            if inInterval {
                self.transitionTo(.inInterval)
            } else {
                // Check if we were in interval state
                let wasInInterval = self.stateQueue.sync { self.internalState == .inInterval }
                if wasInInterval {
                    // If we were in interval and now not, go back to playing
                    self.transitionTo(.playing)
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
            guard let self = self else { return }
            // When session ends, transition to idle
            if !inSession {
                let notIdle = self.stateQueue.sync { self.internalState != .idle }
                if notIdle {
                    self.transitionTo(.idle)
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
