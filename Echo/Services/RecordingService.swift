import AVFoundation
import Combine

/// Manages audio recording functionality
final class RecordingService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isRecording = false
    @Published var isProcessing = false  // New: indicates post-processing
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentRecordingScriptId: UUID?
    @Published var voiceActivityLevel: Float = 0  // 0.0 to 1.0 for UI visualization
    
    // MARK: - Properties
    
    private var audioRecorder: AVAudioRecorder?
    private let fileManager: AudioFileManager
    private let sessionManager: AudioSessionManager
    private var recordingTimer: Timer?
    private var stopRecordingCompletion: ((UUID, TimeInterval) -> Void)?
    
    // Voice activity timestamps for smart trimming
    private var firstSpeakingTime: TimeInterval?
    private var lastSpeakingTime: TimeInterval?
    
    // Dynamic thresholds based on sensitivity setting
    private var voiceDetectionThreshold: Float {
        let sensitivity = UserDefaults.standard.string(forKey: "silenceTrimSensitivity") ?? "medium"
        switch sensitivity {
        case "low":
            return 0.15  // Less sensitive - needs louder voice
        case "high":
            return 0.05  // More sensitive - detects quieter voice
        default:
            return 0.1   // Medium - balanced
        }
    }
    
    private var trimBufferTime: TimeInterval {
        let sensitivity = UserDefaults.standard.string(forKey: "silenceTrimSensitivity") ?? "medium"
        switch sensitivity {
        case "low":
            return 0.5   // More buffer - keeps natural pauses
        case "high":
            return 0.15  // Less buffer - tighter trimming
        default:
            return 0.3   // Medium - balanced
        }
    }
    
    // MARK: - Constants
    
    private enum Constants {
        static let recordingSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,  // Mono is better for voice
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000  // Higher bitrate for better quality
        ]
    }
    
    // MARK: - Initialization
    
    init(fileManager: AudioFileManager, sessionManager: AudioSessionManager) {
        self.fileManager = fileManager
        self.sessionManager = sessionManager
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Start recording for a script
    func startRecording(for scriptId: UUID) throws {
        guard sessionManager.isMicrophonePermissionGranted else {
            throw AudioServiceError.permissionDenied
        }
        
        // Stop any existing recording
        stopRecording()
        
        // Configure session for recording with user's preference
        let enhancedProcessing = UserDefaults.standard.bool(forKey: "voiceEnhancementEnabled")
        try sessionManager.configureForRecording(enhancedProcessing: enhancedProcessing)
        
        let audioURL = fileManager.audioURL(for: scriptId)
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: Constants.recordingSettings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true  // Enable level monitoring
            audioRecorder?.prepareToRecord()
            
            guard audioRecorder?.record() == true else {
                throw AudioServiceError.recordingFailed
            }
            
            currentRecordingScriptId = scriptId
            
            // Reset voice activity timestamps
            firstSpeakingTime = nil
            lastSpeakingTime = nil
            
            DispatchQueue.main.async {
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
            let sensitivity = UserDefaults.standard.string(forKey: "silenceTrimSensitivity") ?? "medium"
            print("RecordingService: Voice activity from \(firstTime)s to \(lastTime)s")
            print("RecordingService: Using \(sensitivity) sensitivity - threshold: \(voiceDetectionThreshold), buffer: \(trimBufferTime)s")
            let trimStart = max(0, firstTime - trimBufferTime)
            let trimEnd = lastTime + trimBufferTime
            print("RecordingService: Will trim to \(trimStart)s - \(trimEnd)s")
        } else {
            print("RecordingService: No voice activity detected - no trimming needed")
        }
        
        if let scriptId = currentRecordingScriptId {
            let duration = recorder.currentTime
            stopRecordingCompletion = { [weak self] _, _ in
                completion?(scriptId, duration)
                self?.stopRecordingCompletion = nil
            }
        }
        
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
        
        recorder.stop()
        stopRecordingTimer()
        
        audioRecorder = nil
        currentRecordingScriptId = nil
        
        DispatchQueue.main.async {
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
                    let sensitivity = UserDefaults.standard.string(forKey: "silenceTrimSensitivity") ?? "medium"
                    print("RecordingService: First speaking detected at \(currentTime)s (sensitivity: \(sensitivity), threshold: \(threshold))")
                }
                self.lastSpeakingTime = currentTime
            }
            
            DispatchQueue.main.async {
                self.recordingDuration = currentTime
                self.voiceActivityLevel = normalizedPower
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
        print("Recording finished successfully: \(flag)")
        
        // Save a copy of the original audio file for transcription
        if let scriptId = currentRecordingScriptId, flag {
            let audioURL = fileManager.audioURL(for: scriptId)
            let originalURL = fileManager.originalAudioURL(for: scriptId)
            
            // Copy the original recording before any processing
            do {
                // Remove existing original if it exists
                if FileManager.default.fileExists(atPath: originalURL.path) {
                    try FileManager.default.removeItem(at: originalURL)
                }
                // Copy the fresh recording as original
                try FileManager.default.copyItem(at: audioURL, to: originalURL)
                print("Saved original audio copy for transcription at: \(originalURL.lastPathComponent)")
            } catch {
                print("Failed to save original audio copy: \(error)")
            }
        }
        
        // Call completion if we have one
        if let scriptId = currentRecordingScriptId {
            let duration = fileManager.getAudioDuration(for: scriptId) ?? 0
            stopRecordingCompletion?(scriptId, duration)
        }
        
        audioRecorder = nil
        currentRecordingScriptId = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingDuration = 0
        }
        stopRecordingTimer()
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Recording encode error: \(error?.localizedDescription ?? "unknown")")
        stopRecording()
    }
}