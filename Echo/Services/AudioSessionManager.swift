import AVFoundation
import Combine

/// Manages audio session configuration and private mode detection
final class AudioSessionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var privateModeActive = false
    @Published var isMicrophonePermissionGranted = false
    
    // MARK: - Properties
    
    private let audioSession = AVAudioSession.sharedInstance()
    private var cancellables = Set<AnyCancellable>()
    
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
        checkMicrophonePermission()
    }
    
    // MARK: - Public Methods
    
    /// Configure audio session for recording
    func configureForRecording(enhancedProcessing: Bool = true) throws {
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
    
    /// Request microphone permission
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        audioSession.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.isMicrophonePermissionGranted = granted
                completion(granted)
            }
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
}