import AVFoundation
import Combine

/// Manages audio recording functionality
final class RecordingService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentRecordingScriptId: UUID?
    
    // MARK: - Properties
    
    private var audioRecorder: AVAudioRecorder?
    private let fileManager: AudioFileManager
    private let sessionManager: AudioSessionManager
    private var recordingTimer: Timer?
    
    // MARK: - Constants
    
    private enum Constants {
        static let recordingSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
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
        
        // Configure session for recording
        try sessionManager.configureForRecording()
        
        let audioURL = fileManager.audioURL(for: scriptId)
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: Constants.recordingSettings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            
            guard audioRecorder?.record() == true else {
                throw AudioServiceError.recordingFailed
            }
            
            currentRecordingScriptId = scriptId
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.recordingDuration = 0
                self.startRecordingTimer()
            }
        } catch {
            throw AudioServiceError.recordingFailed
        }
    }
    
    /// Stop current recording
    @discardableResult
    func stopRecording() -> (scriptId: UUID, duration: TimeInterval)? {
        guard let recorder = audioRecorder, isRecording else { return nil }
        
        recorder.stop()
        stopRecordingTimer()
        
        let scriptId = currentRecordingScriptId
        let duration = recorder.currentTime
        
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
    
    /// Check if currently recording a specific script
    func isRecording(scriptId: UUID) -> Bool {
        isRecording && currentRecordingScriptId == scriptId
    }
    
    // MARK: - Private Methods
    
    private func startRecordingTimer() {
        stopRecordingTimer()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            DispatchQueue.main.async {
                self.recordingDuration = recorder.currentTime
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
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingDuration = 0
        }
        stopRecordingTimer()
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        stopRecording()
    }
}