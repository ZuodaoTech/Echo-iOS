import AVFoundation
import Combine

/// Manages audio recording functionality
final class RecordingService: NSObject {
    
    // MARK: - State Change Callbacks
    
    var onRecordingStateChange: ((Bool) -> Void)?
    var onProcessingStateChange: ((Bool) -> Void)?
    var onDurationUpdate: ((TimeInterval) -> Void)?
    var onVoiceActivityUpdate: ((Float) -> Void)?
    var onCurrentScriptIdChange: ((UUID?) -> Void)?
    
    // MARK: - Internal State (not published)
    
    private(set) var isRecording = false {
        didSet { onRecordingStateChange?(isRecording) }
    }
    
    private(set) var isProcessing = false {
        didSet { onProcessingStateChange?(isProcessing) }
    }
    
    private(set) var recordingDuration: TimeInterval = 0 {
        didSet { onDurationUpdate?(recordingDuration) }
    }
    
    private(set) var currentRecordingScriptId: UUID? {
        didSet { onCurrentScriptIdChange?(currentRecordingScriptId) }
    }
    
    private(set) var voiceActivityLevel: Float = 0 {
        didSet { onVoiceActivityUpdate?(voiceActivityLevel) }
    }
    
    // MARK: - Properties
    
    private var audioRecorder: AVAudioRecorder?
    private let fileManager: AudioFileManager
    private let sessionManager: AudioSessionManager
    private var recordingTimer: Timer?
    private var stopRecordingCompletion: ((UUID, TimeInterval) -> Void)?
    
    // Voice activity timestamps for smart trimming
    private var firstSpeakingTime: TimeInterval?
    private var lastSpeakingTime: TimeInterval?
    
    // Configurable trim parameters from Dev Tools (with defaults)
    private var voiceDetectionThreshold: Float {
        return Float(UserDefaults.standard.double(forKey: "voiceDetectionThreshold").isZero ? 
                    0.15 : UserDefaults.standard.double(forKey: "voiceDetectionThreshold"))
    }
    
    private var trimBufferTime: TimeInterval {
        return UserDefaults.standard.double(forKey: "trimBufferTime").isZero ? 
               0.15 : UserDefaults.standard.double(forKey: "trimBufferTime")
    }
    
    private var maxRecordingDuration: TimeInterval {
        let duration = UserDefaults.standard.double(forKey: "maxRecordingDuration")
        return duration > 0 ? duration : 30.0  // Default to 30 seconds if not set
    }
    
    // MARK: - Constants
    
    private enum Constants {
        static let recordingSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48000,  // Higher sample rate for better quality
            AVNumberOfChannelsKey: 1,  // Mono is better for voice
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,  // Maximum quality
            AVEncoderBitRateKey: 160000  // Higher bitrate for better quality
        ]
    }
    
    // MARK: - Initialization
    
    init(fileManager: AudioFileManager, sessionManager: AudioSessionManager) {
        self.fileManager = fileManager
        self.sessionManager = sessionManager
        super.init()
    }
    
    deinit {
        // Clean up timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Clean up audio recorder
        audioRecorder?.stop()
        audioRecorder = nil
        
        // Clear any pending completion
        stopRecordingCompletion = nil
        
        #if DEBUG
        print("RecordingService: Deinitialized - all resources cleaned up")
        #endif
    }
    
    // MARK: - Public Methods
    
    /// Start recording for a script
    func startRecording(for scriptId: UUID) throws {
        // Check actual permission status, not cached value
        let actualPermission = AVAudioSession.sharedInstance().recordPermission
        guard actualPermission == .granted else {
            #if DEBUG
            print("RecordingService: Permission denied - actual status: \(actualPermission.rawValue)")
            #endif
            throw AudioServiceError.permissionDenied
        }
        
        // Update cached value if it was wrong
        if !sessionManager.isMicrophonePermissionGranted && actualPermission == .granted {
            #if DEBUG
            print("RecordingService: Updating cached permission state")
            #endif
            sessionManager.isMicrophonePermissionGranted = true
        }
        
        // Check available disk space before recording
        do {
            try FileOperationHelper.checkAvailableDiskSpace()
        } catch {
            throw error // Propagate disk space error
        }
        
        // Stop any existing recording
        stopRecording()
        
        // Configure session for recording with voice enhancement always ON
        try sessionManager.configureForRecording(enhancedProcessing: true)
        
        let audioURL = fileManager.audioURL(for: scriptId)
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: Constants.recordingSettings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true  // Enable level monitoring
            audioRecorder?.prepareToRecord()
            
            guard audioRecorder?.record() == true else {
                // Failed to start recording, reset state
                sessionManager.transitionTo(.idle)
                throw AudioServiceError.recordingFailed
            }
            
            // Successfully started recording
            sessionManager.transitionTo(.recording)
            
            // Reset voice activity timestamps
            firstSpeakingTime = nil
            lastSpeakingTime = nil
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentRecordingScriptId = scriptId
                self.isRecording = true
                self.recordingDuration = 0
                self.startRecordingTimer()
            }
        } catch {
            throw AudioServiceError.recordingFailed
        }
    }
    
    /// Stop current recording with completion handler
    func stopRecording(completion: ((UUID, TimeInterval) -> Void)? = nil) {
        guard let recorder = audioRecorder, isRecording else { 
            completion?(UUID(), 0)
            return 
        }
        
        stopRecordingTimer()
        
        // Log the trim points for debugging
        if let firstTime = firstSpeakingTime, let lastTime = lastSpeakingTime {
            #if DEBUG
            print("RecordingService: Voice activity from \(firstTime)s to \(lastTime)s")
            #endif
            #if DEBUG
            print("RecordingService: Using optimized settings - threshold: \(voiceDetectionThreshold), buffer: \(trimBufferTime)s")
            #endif
            let trimStart = max(0, firstTime - trimBufferTime)
            let trimEnd = lastTime + trimBufferTime
            #if DEBUG
            print("RecordingService: Will trim to \(trimStart)s - \(trimEnd)s")
            #endif
        } else {
            #if DEBUG
            print("RecordingService: No voice activity detected - no trimming needed")
            #endif
        }
        
        if let scriptId = currentRecordingScriptId {
            let duration = recorder.currentTime
            stopRecordingCompletion = { [weak self] _, _ in
                completion?(scriptId, duration)
                self?.stopRecordingCompletion = nil
            }
        }
        
        // Transition to transitioning state
        sessionManager.transitionTo(.transitioning)
        
        // This will trigger audioRecorderDidFinishRecording delegate
        recorder.stop()
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingDuration = 0
        }
    }
    
    /// Stop current recording synchronously (legacy support)
    @discardableResult
    func stopRecording() -> (scriptId: UUID, duration: TimeInterval)? {
        guard let recorder = audioRecorder, isRecording else { return nil }
        
        let scriptId = currentRecordingScriptId
        let duration = recorder.currentTime
        
        // Transition to transitioning state
        sessionManager.transitionTo(.transitioning)
        
        recorder.stop()
        stopRecordingTimer()
        
        audioRecorder = nil
        
        // Transition back to idle after stopping
        sessionManager.transitionTo(.idle)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentRecordingScriptId = nil
            self.isRecording = false
            self.recordingDuration = 0
        }
        
        if let scriptId = scriptId {
            return (scriptId, duration)
        }
        return nil
    }
    
    /// Pause recording
    func pauseRecording() {
        audioRecorder?.pause()
        stopRecordingTimer()
    }
    
    /// Resume recording
    func resumeRecording() {
        audioRecorder?.record()
        if isRecording {
            startRecordingTimer()
        }
    }
    
    /// Get current recording time
    var currentTime: TimeInterval {
        audioRecorder?.currentTime ?? 0
    }
    
    /// Get the trim timestamps based on voice activity
    func getTrimTimestamps() -> (start: TimeInterval, end: TimeInterval)? {
        guard let firstTime = firstSpeakingTime,
              let lastTime = lastSpeakingTime else {
            return nil
        }
        
        // Add buffer time before first speech and after last speech
        let trimStart = max(0, firstTime - trimBufferTime)
        let trimEnd = lastTime + trimBufferTime
        
        return (trimStart, trimEnd)
    }
    
    /// Check if currently recording a specific script
    func isRecording(scriptId: UUID) -> Bool {
        isRecording && currentRecordingScriptId == scriptId
    }
    
    // MARK: - Private Methods
    
    private func startRecordingTimer() {
        stopRecordingTimer()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            
            // Update audio levels for voice activity monitoring
            recorder.updateMeters()
            let averagePower = recorder.averagePower(forChannel: 0)
            
            // Convert dB to linear scale (0.0 to 1.0)
            // -160 dB (silence) to 0 dB (maximum)
            let minDb: Float = -60
            let normalizedPower = max(0, min(1, (averagePower - minDb) / -minDb))
            
            // Track speaking timestamps
            let currentTime = recorder.currentTime
            let threshold = self.voiceDetectionThreshold
            if normalizedPower > threshold {
                // Speaking detected
                if self.firstSpeakingTime == nil {
                    self.firstSpeakingTime = currentTime
                    #if DEBUG
                    print("RecordingService: First speaking detected at \(currentTime)s (threshold: \(threshold))")
                    #endif
                }
                self.lastSpeakingTime = currentTime
            }
            
            DispatchQueue.main.async {
                self.recordingDuration = currentTime
                self.voiceActivityLevel = normalizedPower
                
                // Auto-stop at max duration
                if currentTime >= self.maxRecordingDuration {
                    #if DEBUG
                    print("RecordingService: Maximum recording duration reached (\(Int(self.maxRecordingDuration))s)")
                    #endif
                    self.stopRecording()
                }
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}

// MARK: - AVAudioRecorderDelegate

extension RecordingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        #if DEBUG
        print("🎤 Recording finished successfully: \(flag)")
        #endif
        
        // IMPORTANT: Transition to idle state immediately after recording finishes
        // This ensures the audio session is ready for playback
        sessionManager.transitionTo(.idle)
        #if DEBUG
        print("🟢 Audio session ready for playback")
        #endif
        
        // Save a copy of the original audio file for transcription
        if let scriptId = currentRecordingScriptId, flag {
            let audioURL = fileManager.audioURL(for: scriptId)
            let originalURL = fileManager.originalAudioURL(for: scriptId)
            
            // Copy the original recording before any processing with proper error handling
            do {
                // Use helper with retry logic
                try FileOperationHelper.copyFile(from: audioURL, to: originalURL)
                #if DEBUG
                print("Saved original audio copy for transcription at: \(originalURL.lastPathComponent)")
                #endif
            } catch let error as AudioServiceError {
                #if DEBUG
                print("Failed to save original audio copy: \(error.errorDescription ?? "")")
                #endif
                // Continue even if copy fails - the main recording is still valid
            } catch {
                #if DEBUG
                print("Failed to save original audio copy: \(error)")
                #endif
            }
        }
        
        // Call completion if we have one
        if let scriptId = currentRecordingScriptId {
            let duration = fileManager.getAudioDuration(for: scriptId) ?? 0
            stopRecordingCompletion?(scriptId, duration)
        }
        
        audioRecorder = nil
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentRecordingScriptId = nil
            self.isRecording = false
            self.recordingDuration = 0
        }
        stopRecordingTimer()
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        #if DEBUG
        print("Recording encode error: \(error?.localizedDescription ?? "unknown")")
        #endif
        stopRecording()
    }
}