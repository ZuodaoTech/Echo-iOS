import AVFoundation
import Combine
import os

/// Defines the possible states of the audio session
enum AudioSessionState: String, CaseIterable {
    case idle = "Idle"
    case preparingToRecord = "Preparing to Record"
    case recording = "Recording"
    case preparingToPlay = "Preparing to Play"
    case playing = "Playing"
    case paused = "Paused"
    case transitioning = "Transitioning"
    case error = "Error"
    
    /// Determines if a transition to the target state is valid
    func canTransition(to target: AudioSessionState) -> Bool {
        switch (self, target) {
        // From idle, can go to preparing states
        case (.idle, .preparingToRecord), (.idle, .preparingToPlay):
            return true
            
        // From preparing to record, can go to recording or back to idle
        case (.preparingToRecord, .recording), (.preparingToRecord, .idle):
            return true
            
        // From recording, can go to transitioning (stopping) or error
        case (.recording, .transitioning), (.recording, .error):
            return true
            
        // From preparing to play, can go to playing or back to idle
        case (.preparingToPlay, .playing), (.preparingToPlay, .idle):
            return true
            
        // From playing, can go to paused, transitioning (stopping), or error
        case (.playing, .paused), (.playing, .transitioning), (.playing, .error):
            return true
            
        // From paused, can go back to playing or transitioning (stopping)
        case (.paused, .playing), (.paused, .transitioning):
            return true
            
        // From transitioning, can go to idle or error
        case (.transitioning, .idle), (.transitioning, .error):
            return true
            
        // From error, can go to idle (reset)
        case (.error, .idle):
            return true
            
        // All other transitions are invalid
        default:
            return false
        }
    }
}

/// Manages audio session configuration and private mode detection
final class AudioSessionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var privateModeActive = false
    @Published var isMicrophonePermissionGranted = false
    @Published private(set) var currentState: AudioSessionState = .idle
    
    // MARK: - Properties
    
    private let audioSession = AVAudioSession.sharedInstance()
    private var cancellables = Set<AnyCancellable>()
    
    // Thread safety
    private let stateLock = NSLock()
    private let logger = Logger(subsystem: "xiaolai.Echo", category: "AudioSession")
    
    // Permission checking task to prevent race conditions
    private var permissionCheckTask: Task<Bool, Never>?
    
    // MARK: - Constants
    
    private enum Constants {
        static let audioSampleRate: Double = 44100
        static let audioBufferDuration: TimeInterval = 0.005
    }
    
    // MARK: - Initialization
    
    init() {
        setupAudioSession()
        setupNotifications()
        checkPrivateMode()
        
        // Check initial permission state asynchronously
        Task { @MainActor in
            await checkAndCacheMicrophonePermission()
        }
    }
    
    // MARK: - Public Methods
    
    /// Configure audio session for recording
    func configureForRecording(enhancedProcessing: Bool = true) throws {
        // Check if we can start recording
        guard canStartRecording else {
            logger.error("Cannot start recording in current state: \(self.currentState.rawValue)")
            throw AudioServiceError.invalidState("Cannot start recording while \(currentState.rawValue)")
        }
        
        // Transition to preparing state
        guard transitionTo(.preparingToRecord) else {
            throw AudioServiceError.invalidState("Failed to transition to preparingToRecord state")
        }
        
        do {
            // Use measurement mode for MAXIMUM noise reduction
            // measurement mode provides the most aggressive audio processing
            let mode: AVAudioSession.Mode = enhancedProcessing ? .measurement : .default
            
            // measurement mode enables MAXIMUM:
            // ✅ Echo cancellation (AEC) - Most aggressive
            // ✅ Noise suppression - Maximum level
            // ✅ Automatic gain control (AGC) - Optimized for voice
            // ✅ Voice activity detection (VAD) - Enhanced
            // ✅ Wide-band speech mode - Better frequency response
            
            // Additional options for better quality
            var options: AVAudioSession.CategoryOptions = [
                .defaultToSpeaker,      // Use speaker by default
                .allowBluetooth,        // Allow Bluetooth devices
                .interruptSpokenAudioAndMixWithOthers  // Better handling
            ]
            
            // iOS 13+ enhancement
            if #available(iOS 13.0, *) {
                options.insert(.allowBluetoothA2DP)  // Higher quality Bluetooth
            }
            
            try audioSession.setCategory(.playAndRecord, 
                                        mode: mode,
                                        options: options)
            
            // Set preferred sample rate for better quality
            try audioSession.setPreferredSampleRate(48000)  // Higher than 44100
            
            // Set preferred input gain if available (iOS 14+)
            if #available(iOS 14.0, *) {
                if audioSession.isInputGainSettable {
                    try audioSession.setInputGain(1.0)  // Maximum gain
                }
            }
            
            print("🎤 Recording mode: Maximum noise reduction (measurement mode)")
            // Only activate if not already active
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true)
            }
        } catch {
            // On simulator, some configurations may fail - that's OK
            #if targetEnvironment(simulator)
            // Silently ignore on simulator
            #else
            throw error
            #endif
        }
    }
    
    /// Configure audio session for playback
    func configureForPlayback() throws {
        // Check if we can start playback
        guard canStartPlayback else {
            logger.error("Cannot start playback in current state: \(self.currentState.rawValue)")
            throw AudioServiceError.invalidState("Cannot start playback while \(currentState.rawValue)")
        }
        
        // Transition to preparing state
        guard transitionTo(.preparingToPlay) else {
            throw AudioServiceError.invalidState("Failed to transition to preparingToPlay state")
        }
        
        do {
            // Only change category if needed
            if audioSession.category != .playback {
                try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
            }
            // Only activate if not already active
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true)
            }
        } catch {
            // On simulator, some configurations may fail - that's OK
            #if targetEnvironment(simulator)
            // Silently ignore on simulator
            #else
            throw error
            #endif
        }
    }
    
    // MARK: - Microphone Permission Management (Async/Await)
    
    /// Request microphone permission using async/await with race condition prevention
    @MainActor
    func requestMicrophonePermission() async -> Bool {
        // Check cached state first
        if isMicrophonePermissionGranted {
            logger.info("Microphone permission already granted (cached)")
            return true
        }
        
        // Use Task to ensure sequential permission checking
        if let existingTask = permissionCheckTask {
            return await existingTask.value
        }
        
        // Create a new task for permission request
        let task = Task { @MainActor () -> Bool in
            let currentStatus = self.audioSession.recordPermission
            
            switch currentStatus {
            case .granted:
                self.isMicrophonePermissionGranted = true
                self.permissionCheckTask = nil
                return true
                
            case .denied:
                self.isMicrophonePermissionGranted = false
                self.logger.warning("Microphone permission denied by user")
                self.permissionCheckTask = nil
                return false
                
            case .undetermined:
                // Request permission
                let granted = await withCheckedContinuation { continuation in
                    self.audioSession.requestRecordPermission { [weak self] granted in
                        DispatchQueue.main.async {
                            self?.isMicrophonePermissionGranted = granted
                            self?.logger.info("Microphone permission request result: \(granted)")
                            self?.permissionCheckTask = nil
                            continuation.resume(returning: granted)
                        }
                    }
                }
                return granted
                
            @unknown default:
                self.logger.error("Unknown microphone permission status")
                self.permissionCheckTask = nil
                return false
            }
        }
        
        permissionCheckTask = task
        return await task.value
    }
    
    /// Check microphone permission status using async/await
    @MainActor
    func checkMicrophonePermission() async -> Bool {
        // If we have an ongoing check, wait for it
        if let existingTask = permissionCheckTask {
            return await existingTask.value
        }
        
        // Create new check task
        let task = Task { @MainActor in
            let permission = self.audioSession.recordPermission
            let granted = permission == .granted
            
            // Cache the result
            self.isMicrophonePermissionGranted = granted
            self.permissionCheckTask = nil
            
            return granted
        }
        
        permissionCheckTask = task
        return await task.value
    }
    
    /// Check and cache microphone permission state
    @MainActor
    private func checkAndCacheMicrophonePermission() async {
        _ = await checkMicrophonePermission()
    }
    
    /// Refresh permission state when app becomes active
    func refreshPermissionState() {
        Task { @MainActor in
            await checkAndCacheMicrophonePermission()
        }
    }
    
    // MARK: - Legacy Permission Methods (for backward compatibility)
    
    /// Request microphone permission (legacy completion handler)
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        Task {
            let granted = await requestMicrophonePermission()
            completion(granted)
        }
    }
    
    /// Check if earphones are connected (for private mode)
    func checkPrivateMode() {
        let currentRoute = audioSession.currentRoute
        var hasEarphones = false
        
        for output in currentRoute.outputs {
            let portType = output.portType
            if portType == .headphones ||
               portType == .bluetoothA2DP ||
               portType == .bluetoothHFP ||
               portType == .bluetoothLE {
                hasEarphones = true
                break
            }
        }
        
        DispatchQueue.main.async {
            self.privateModeActive = !hasEarphones
        }
    }
    
    /// Deactivate audio session
    func deactivateSession() {
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            
            // Only set preferred properties on real device
            // These cause error -50 on simulator even with compile-time check
            #if !targetEnvironment(simulator)
            do {
                try audioSession.setPreferredSampleRate(Constants.audioSampleRate)
                try audioSession.setPreferredIOBufferDuration(Constants.audioBufferDuration)
            } catch {
                // Ignore preferred setting errors - not critical
            }
            #endif
            
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] _ in
                self?.checkPrivateMode()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleInterruption(notification)
            }
            .store(in: &cancellables)
    }
    
    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began - playback/recording will be paused
            break
        case .ended:
            // Interruption ended - can resume if needed
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Can resume playback/recording
                }
            }
        @unknown default:
            break
        }
    }
    
    private func checkMicrophonePermission() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isMicrophonePermissionGranted = self.audioSession.recordPermission == .granted
        }
    }
    
    // MARK: - State Management
    
    /// Attempts to transition to a new state
    /// - Parameter newState: The target state
    /// - Returns: True if the transition was successful, false otherwise
    @discardableResult
    func transitionTo(_ newState: AudioSessionState) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        let oldState = currentState
        
        // Check if transition is valid
        guard oldState.canTransition(to: newState) else {
            logger.warning("Invalid state transition from \(oldState.rawValue) to \(newState.rawValue)")
            return false
        }
        
        // Perform the transition
        logger.info("State transition: \(oldState.rawValue) → \(newState.rawValue)")
        
        DispatchQueue.main.async { [weak self] in
            self?.currentState = newState
        }
        
        return true
    }
    
    /// Force reset to idle state (use only for error recovery)
    func resetToIdle() {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        logger.warning("Force resetting audio session to idle state")
        
        // Deactivate session first
        deactivateSession()
        
        DispatchQueue.main.async { [weak self] in
            self?.currentState = .idle
        }
    }
    
    /// Check if the current state allows recording
    var canStartRecording: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        return currentState == .idle
    }
    
    /// Check if the current state allows playback
    var canStartPlayback: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        return currentState == .idle
    }
    
    /// Check if currently in a recording state
    var isInRecordingState: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        return currentState == .preparingToRecord || currentState == .recording
    }
    
    /// Check if currently in a playback state
    var isInPlaybackState: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        return currentState == .preparingToPlay || currentState == .playing || currentState == .paused
    }
}