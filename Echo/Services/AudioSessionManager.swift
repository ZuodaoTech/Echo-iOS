import AVFoundation
import Combine

/// Manages audio session configuration and privacy mode detection
final class AudioSessionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var privacyModeActive = false
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
        checkPrivacyMode()
        checkMicrophonePermission()
    }
    
    // MARK: - Public Methods
    
    /// Configure audio session for recording
    func configureForRecording() throws {
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true)
    }
    
    /// Configure audio session for playback
    func configureForPlayback() throws {
        try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
        try audioSession.setActive(true)
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
    
    /// Check if earphones are connected (for privacy mode)
    func checkPrivacyMode() {
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
            self.privacyModeActive = !hasEarphones
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
            
            #if !targetEnvironment(simulator)
            try audioSession.setPreferredSampleRate(Constants.audioSampleRate)
            try audioSession.setPreferredIOBufferDuration(Constants.audioBufferDuration)
            #endif
            
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] _ in
                self?.checkPrivacyMode()
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
        isMicrophonePermissionGranted = audioSession.recordPermission == .granted
    }
}