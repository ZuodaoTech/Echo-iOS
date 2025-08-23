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
    @Published var isPaused = false
    @Published var currentPlayingScriptId: UUID?
    @Published var playbackProgress: Double = 0
    @Published var privacyModeActive = false
    @Published var currentRepetition: Int = 0
    @Published var totalRepetitions: Int = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var repetitionTimer: Timer?
    private var completionTimer: Timer?
    private var currentScript: SelftalkScript?
    private var pausedTime: TimeInterval = 0
    private var playbackSessionID: UUID?
    private var isHandlingCompletion = false
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    override init() {
        super.init()
        setupAudioSession()
        setupNotifications()
        checkPrivacyMode()
    }
    
    private func setupAudioSession() {
        do {
            // Configure audio session with proper options
            try audioSession.setCategory(.playAndRecord, 
                                        mode: .default, 
                                        options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            
            // Set preferred settings to avoid warnings (only on real device)
            #if !targetEnvironment(simulator)
            try audioSession.setPreferredSampleRate(44100)
            try audioSession.setPreferredIOBufferDuration(0.005)
            #endif
            
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
        // If we're paused on the same script, resume instead
        if isPaused && currentPlayingScriptId == script.id {
            resumePlayback()
            return
        }
        
        guard !script.privacyModeEnabled || !privacyModeActive else {
            throw AudioServiceError.privacyModeActive
        }
        
        guard let audioURL = script.audioFileURL,
              FileManager.default.fileExists(atPath: audioURL.path) else {
            throw AudioServiceError.noRecording
        }
        
        stopPlayback()
        
        do {
            // Create a new playback session
            playbackSessionID = UUID()
            let sessionID = playbackSessionID!
            
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            // Enable audio finishing callback
            audioPlayer?.enableRate = true
            
            currentScript = script
            currentRepetition = 1
            totalRepetitions = Int(script.repetitions)
            pausedTime = 0
            
            print("Starting playback session \(sessionID): repetition 1 of \(totalRepetitions)")
            print("Audio duration: \(audioPlayer?.duration ?? 0) seconds")
            
            let didPlay = audioPlayer?.play() ?? false
            
            if didPlay {
                DispatchQueue.main.async {
                    self.isPlaying = true
                    self.isPaused = false
                    self.currentPlayingScriptId = script.id
                    script.incrementPlayCount()
                }
                
                startProgressTimer()
                
                // Also start monitoring for completion in case delegate doesn't fire
                startCompletionMonitor()
            } else {
                print("Failed to start playback")
                throw AudioServiceError.playbackFailed
            }
        } catch {
            throw AudioServiceError.playbackFailed
        }
    }
    
    func pausePlayback() {
        guard let player = audioPlayer, isPlaying else { return }
        
        player.pause()
        pausedTime = player.currentTime
        
        // Cancel completion timer when pausing
        completionTimer?.invalidate()
        completionTimer = nil
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isPaused = true
        }
        stopProgressTimer()
    }
    
    func resumePlayback() {
        guard let player = audioPlayer, isPaused else { return }
        
        player.currentTime = pausedTime
        player.play()
        
        DispatchQueue.main.async {
            self.isPlaying = true
            self.isPaused = false
        }
        startProgressTimer()
        
        // Restart completion monitor from current position
        let remainingDuration = player.duration - pausedTime + 0.1
        completionTimer = Timer.scheduledTimer(withTimeInterval: remainingDuration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if let player = self.audioPlayer, !player.isPlaying {
                print("Completion monitor detected playback ended after resume")
                self.handlePlaybackCompletion()
            }
        }
    }
    
    func stopPlayback() {
        print("Stopping playback for session \(playbackSessionID?.uuidString ?? "none")")
        
        audioPlayer?.stop()
        audioPlayer = nil
        currentScript = nil
        pausedTime = 0
        playbackSessionID = nil
        isHandlingCompletion = false
        
        repetitionTimer?.invalidate()
        repetitionTimer = nil
        
        completionTimer?.invalidate()
        completionTimer = nil
        
        // Reset counters immediately to prevent race conditions
        currentRepetition = 0
        totalRepetitions = 0
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isPaused = false
            self.currentPlayingScriptId = nil
            self.playbackProgress = 0
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
    
    // MARK: - Completion Monitor
    
    private func startCompletionMonitor() {
        // Stop any existing completion timer
        completionTimer?.invalidate()
        completionTimer = nil
        
        guard let player = audioPlayer else { 
            print("No audio player to monitor")
            return 
        }
        
        // Capture the current session ID
        let sessionID = playbackSessionID
        
        // Set up a timer to check if playback has completed
        // Check slightly after the expected duration
        let checkInterval = player.duration + 0.1
        
        print("Setting up completion monitor for \(checkInterval) seconds (duration: \(player.duration))")
        
        // Use asyncAfter instead of Timer for more reliable execution
        DispatchQueue.main.asyncAfter(deadline: .now() + checkInterval) { [weak self] in
            guard let self = self else {
                print("AudioService was deallocated during playback")
                return
            }
            
            // Check if this is still the same playback session
            guard self.playbackSessionID == sessionID else {
                print("Ignoring completion check from old session")
                return
            }
            
            print("Completion check - isPlaying: \(self.audioPlayer?.isPlaying ?? false)")
            
            // Only handle completion if player exists and is not playing
            if let player = self.audioPlayer, !player.isPlaying {
                print("Playback completed - handling completion")
                self.handlePlaybackCompletion()
            }
        }
    }
    
    private func handlePlaybackCompletion() {
        // Prevent double handling
        guard !isHandlingCompletion else {
            print("Already handling completion, skipping duplicate call")
            return
        }
        
        guard let script = currentScript else {
            stopPlayback()
            return
        }
        
        // Mark that we're handling completion
        isHandlingCompletion = true
        
        print("Handling playback completion for repetition \(currentRepetition) of \(totalRepetitions)")
        
        // Cancel any pending completion timer since we're handling it now
        completionTimer?.invalidate()
        completionTimer = nil
        
        // Check if we have more repetitions to play
        if currentRepetition < totalRepetitions {
            // We need to play more repetitions
            currentRepetition += 1
            playbackProgress = 0
            
            print("Will play repetition \(currentRepetition) after \(script.intervalSeconds) second interval")
            
            // Stop the progress timer during interval
            stopProgressTimer()
            
            // Play next repetition after interval
            DispatchQueue.main.asyncAfter(deadline: .now() + script.intervalSeconds) { [weak self] in
                guard let self = self else { 
                    print("AudioService was deallocated")
                    return 
                }
                
                // Reset the handling flag for the next playback
                self.isHandlingCompletion = false
                
                print("Playing repetition \(self.currentRepetition) of \(self.totalRepetitions)")
                
                // Make sure we still have the player
                guard let player = self.audioPlayer else {
                    print("Audio player is nil, cannot continue repetitions")
                    return
                }
                
                // Reset and play
                player.currentTime = 0
                player.prepareToPlay()
                
                if player.play() {
                    print("Successfully started repetition \(self.currentRepetition)")
                    self.startProgressTimer()
                    self.startCompletionMonitor()
                } else {
                    print("Failed to play repetition \(self.currentRepetition)")
                    self.stopPlayback()
                }
            }
        } else {
            // All repetitions completed
            print("All \(totalRepetitions) repetitions completed")
            stopPlayback()
        }
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
        print("AVAudioPlayerDelegate: audioPlayerDidFinishPlaying called, successfully: \(flag)")
        print("Current session: \(playbackSessionID?.uuidString ?? "none"), Repetition: \(currentRepetition) of \(totalRepetitions)")
        
        // Ignore if we don't have an active session (old delegate callback)
        guard playbackSessionID != nil else {
            print("Ignoring delegate callback - no active session")
            return
        }
        
        // Cancel the completion timer since delegate fired
        completionTimer?.invalidate()
        completionTimer = nil
        
        // Use the common completion handler
        handlePlaybackCompletion()
    }
}