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
    
    // Optimized for noisy environments with tight trimming
    private var voiceDetectionThreshold: Float {
        return 0.15  // Low sensitivity - filters background noise better
    }
    
    private var trimBufferTime: TimeInterval {
        return 0.15  // Short buffer - tighter trimming
    }
    
    // MARK: - Constants
    
    private enum Constants {
        static let maxRecordingDuration: TimeInterval = 60.0  // 60 seconds max
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
        SecureLogger.debug("RecordingService deinitialized - all resources cleaned up")
        #endif
    }
    
    // MARK: - Public Methods
    
    /// Start recording for a script
    func startRecording(for scriptId: UUID) throws {
        guard sessionManager.isMicrophonePermissionGranted else {
            throw AudioServiceError.permissionDenied
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
            SecureLogger.debug("Voice activity from \(String(format: "%.2f", firstTime))s to \(String(format: "%.2f", lastTime))s")
            SecureLogger.debug("Using optimized settings - threshold: \(voiceDetectionThreshold), buffer: \(trimBufferTime)s")
            #endif
            let trimStart = max(0, firstTime - trimBufferTime)
            let trimEnd = lastTime + trimBufferTime
            #if DEBUG
            SecureLogger.debug("Will trim to \(String(format: "%.2f", trimStart))s - \(String(format: "%.2f", trimEnd))s")
            #endif
        } else {
            #if DEBUG
            SecureLogger.debug("No voice activity detected - no trimming needed")
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
                    SecureLogger.debug("First speaking detected at \(String(format: "%.2f", currentTime))s")
                    #endif
                }
                self.lastSpeakingTime = currentTime
            }
            
            DispatchQueue.main.async {
                self.recordingDuration = currentTime
                self.voiceActivityLevel = normalizedPower
                
                // Auto-stop at max duration
                if currentTime >= Constants.maxRecordingDuration {
                    SecureLogger.warning("Maximum recording duration reached (60s)")
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
        SecureLogger.debug("Recording finished successfully: \(flag)")
        #endif
        
        // IMPORTANT: Transition to idle state immediately after recording finishes
        // This ensures the audio session is ready for playback
        sessionManager.transitionTo(.idle)
        #if DEBUG
        SecureLogger.debug("Audio session ready for playback")
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
                SecureLogger.debug("Saved original audio copy for transcription")
                #endif
            } catch let error as AudioServiceError {
                SecureLogger.warning("Failed to save original audio copy: \(error.errorDescription ?? "Unknown error")")
                // Continue even if copy fails - the main recording is still valid
            } catch {
                SecureLogger.warning("Failed to save original audio copy: \(error.localizedDescription)")
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
        SecureLogger.error("Recording encode error: \(error?.localizedDescription ?? "unknown")")
        stopRecording()
    }
}