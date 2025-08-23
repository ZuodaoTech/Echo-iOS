import AVFoundation
import Combine
import SwiftUI

enum AudioServiceError: LocalizedError {
    case privacyModeActive
    case recordingFailed
    case playbackFailed
    case noRecording
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .privacyModeActive:
            return "Please connect earphones to play audio"
        case .recordingFailed:
            return "Failed to record audio"
        case .playbackFailed:
            return "Failed to play audio"
        case .noRecording:
            return "No recording available"
        case .permissionDenied:
            return "Microphone permission denied"
        }
    }
}

class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()
    
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var currentPlayingScriptId: UUID?
    @Published var playbackProgress: Double = 0
    @Published var privacyModeActive = false
    @Published var currentRepetition: Int = 0
    @Published var totalRepetitions: Int = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var repetitionTimer: Timer?
    private var currentScript: SelftalkScript?
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    override init() {
        super.init()
        setupAudioSession()
        setupNotifications()
        checkPrivacyMode()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func audioRouteChanged(_ notification: Notification) {
        checkPrivacyMode()
    }
    
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
    
    // MARK: - Recording
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        audioSession.requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func startRecording(for script: SelftalkScript) throws {
        guard audioSession.recordPermission == .granted else {
            throw AudioServiceError.permissionDenied
        }
        
        stopPlayback()
        
        let audioURL = getAudioURL(for: script.id)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            currentScript = script
            
            DispatchQueue.main.async {
                self.isRecording = true
                script.audioFilePath = audioURL.path
            }
        } catch {
            throw AudioServiceError.recordingFailed
        }
    }
    
    func stopRecording() {
        if let recorder = audioRecorder {
            recorder.stop()
            
            // Get the duration of the recording
            if let script = currentScript {
                let audioURL = getAudioURL(for: script.id)
                if let player = try? AVAudioPlayer(contentsOf: audioURL) {
                    script.audioDuration = player.duration
                }
            }
        }
        
        audioRecorder = nil
        currentScript = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    // MARK: - Playback
    
    func play(script: SelftalkScript) throws {
        guard !script.privacyModeEnabled || !privacyModeActive else {
            throw AudioServiceError.privacyModeActive
        }
        
        guard let audioURL = script.audioFileURL,
              FileManager.default.fileExists(atPath: audioURL.path) else {
            throw AudioServiceError.noRecording
        }
        
        stopPlayback()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            
            currentScript = script
            currentRepetition = 1
            totalRepetitions = Int(script.repetitions)
            
            audioPlayer?.play()
            
            DispatchQueue.main.async {
                self.isPlaying = true
                self.currentPlayingScriptId = script.id
                script.incrementPlayCount()
            }
            
            startProgressTimer()
        } catch {
            throw AudioServiceError.playbackFailed
        }
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        DispatchQueue.main.async {
            self.isPlaying = false
        }
        stopProgressTimer()
    }
    
    func resumePlayback() {
        audioPlayer?.play()
        DispatchQueue.main.async {
            self.isPlaying = true
        }
        startProgressTimer()
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentScript = nil
        
        repetitionTimer?.invalidate()
        repetitionTimer = nil
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentPlayingScriptId = nil
            self.playbackProgress = 0
            self.currentRepetition = 0
            self.totalRepetitions = 0
        }
        
        stopProgressTimer()
    }
    
    func setPlaybackSpeed(_ speed: Float) {
        audioPlayer?.rate = speed
    }
    
    // MARK: - Progress Timer
    
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = self.audioPlayer else { return }
            DispatchQueue.main.async {
                self.playbackProgress = player.currentTime / player.duration
            }
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    // MARK: - Helper Methods
    
    private func getAudioURL(for scriptId: UUID) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioPath = documentsPath.appendingPathComponent("Recordings")
        
        if !FileManager.default.fileExists(atPath: audioPath.path) {
            try? FileManager.default.createDirectory(at: audioPath, withIntermediateDirectories: true)
        }
        
        return audioPath.appendingPathComponent("\(scriptId.uuidString).m4a")
    }
    
    func deleteRecording(for script: SelftalkScript) {
        guard let audioURL = script.audioFileURL else { return }
        
        if currentPlayingScriptId == script.id {
            stopPlayback()
        }
        
        try? FileManager.default.removeItem(at: audioURL)
        script.audioFilePath = nil
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard let script = currentScript else {
            stopPlayback()
            return
        }
        
        if currentRepetition < totalRepetitions {
            // More repetitions to go
            currentRepetition += 1
            
            DispatchQueue.main.async {
                self.playbackProgress = 0
            }
            
            // Wait for the interval before playing again
            repetitionTimer = Timer.scheduledTimer(withTimeInterval: script.intervalSeconds, repeats: false) { _ in
                self.audioPlayer?.play()
                self.startProgressTimer()
            }
        } else {
            // All repetitions completed
            stopPlayback()
        }
    }
}