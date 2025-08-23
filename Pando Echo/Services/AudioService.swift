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
    
    // MARK: - Constants
    private enum Constants {
        static let progressUpdateInterval: TimeInterval = 0.1
        static let intervalTimerUpdateInterval: TimeInterval = 0.02
        static let completionCheckDelay: TimeInterval = 0.1
        static let audioSampleRate: Double = 44100
        static let audioBufferDuration: TimeInterval = 0.005
        static let intervalDebugPrintInterval: TimeInterval = 0.5
    }
    
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var isInPlaybackSession = false  // True during entire playback including intervals
    @Published var currentPlayingScriptId: UUID?
    @Published var playbackProgress: Double = 0
    @Published var privacyModeActive = false
    @Published var currentRepetition: Int = 0
    @Published var totalRepetitions: Int = 0
    @Published var isInInterval = false
    @Published var intervalProgress: Double = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var repetitionTimer: Timer?
    private var completionTimer: Timer?
    private var intervalTimer: Timer?
    private var currentScript: SelftalkScript?
    private var pausedTime: TimeInterval = 0
    private var playbackSessionID: UUID?
    private var isHandlingCompletion = false
    private var intervalStartTime: Date?
    private var intervalPausedTime: TimeInterval = 0  // How long into the interval we paused
    private var nextRepetitionWorkItem: DispatchWorkItem?  // Track scheduled next repetition
    
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
            try audioSession.setPreferredSampleRate(Constants.audioSampleRate)
            try audioSession.setPreferredIOBufferDuration(Constants.audioBufferDuration)
            #endif
            
            try audioSession.setActive(true)
        } catch {
            // Failed to setup audio session
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
            AVSampleRateKey: Constants.audioSampleRate,
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
            
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            // Enable audio finishing callback
            audioPlayer?.enableRate = true
            
            currentScript = script
            currentRepetition = 1
            totalRepetitions = Int(script.repetitions)
            pausedTime = 0
            
            // Starting playback session
            
            let didPlay = audioPlayer?.play() ?? false
            
            if didPlay {
                DispatchQueue.main.async {
                    self.isPlaying = true
                    self.isPaused = false
                    self.isInPlaybackSession = true  // Start of playback session
                    self.currentPlayingScriptId = script.id
                    script.incrementPlayCount()
                }
                
                startProgressTimer()
                
                // Also start monitoring for completion in case delegate doesn't fire
                startCompletionMonitor()
            } else {
                // Failed to start playback
                throw AudioServiceError.playbackFailed
            }
        } catch {
            throw AudioServiceError.playbackFailed
        }
    }
    
    func pausePlayback() {
        // Allow pausing during intervals or actual playback
        guard isInPlaybackSession else { return }
        
        // Check interval first since audio might have just finished
        if isInInterval {
            // Pausing during interval - stop the interval timer and save progress
            if let startTime = intervalStartTime {
                // Save how much time has elapsed since start (or resume)
                intervalPausedTime = Date().timeIntervalSince(startTime)
                // Pausing interval
            }
            intervalTimer?.invalidate()
            intervalTimer = nil
            intervalStartTime = nil  // Clear so next resume knows to set it
            
            // Cancel the scheduled next repetition
            nextRepetitionWorkItem?.cancel()
            nextRepetitionWorkItem = nil
        } else if let player = audioPlayer, player.isPlaying {
            // Pause actual audio playback (check player.isPlaying not our state)
            player.pause()
            pausedTime = player.currentTime
            
            // Cancel completion timer when pausing
            completionTimer?.invalidate()
            completionTimer = nil
            
            stopProgressTimer()
        }
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isPaused = true
            // Keep isInPlaybackSession true
        }
    }
    
    func resumePlayback() {
        guard isPaused && isInPlaybackSession else { return }
        
        if isInInterval, let script = currentScript {
            // Resume interval countdown first since we check it first in pause
            resumeInterval(script: script)
        } else if let player = audioPlayer {
            // Resume audio playback
            player.currentTime = pausedTime
            player.play()
            
            DispatchQueue.main.async {
                self.isPlaying = true
                self.isPaused = false
            }
            startProgressTimer()
            
            // Restart completion monitor from current position
            let remainingDuration = player.duration - pausedTime + Constants.completionCheckDelay
            completionTimer = Timer.scheduledTimer(withTimeInterval: remainingDuration, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                if let player = self.audioPlayer, !player.isPlaying {
                    // Completion monitor detected playback ended after resume
                    self.handlePlaybackCompletion()
                }
            }
        }
    }
    
    private func resumeInterval(script: SelftalkScript) {
        // Resume interval countdown
        DispatchQueue.main.async {
            self.isPaused = false
            
            // Continue interval timer from where we left off
            let remainingInterval = script.intervalSeconds - self.intervalPausedTime
            // Resuming interval
            
            // Set start time adjusted for the time already elapsed
            self.intervalStartTime = Date().addingTimeInterval(-self.intervalPausedTime)
            self.startIntervalTimer(duration: script.intervalSeconds)
            
            // Cancel any existing work item
            self.nextRepetitionWorkItem?.cancel()
            
            // Schedule next repetition after remaining interval
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, !self.isPaused else { return }
                self.playNextRepetition()
            }
            self.nextRepetitionWorkItem = workItem
            
            DispatchQueue.main.asyncAfter(deadline: .now() + remainingInterval, execute: workItem)
        }
    }
    
    func stopPlayback() {
        // Stopping playback
        
        audioPlayer?.stop()
        audioPlayer = nil
        currentScript = nil
        pausedTime = 0
        intervalPausedTime = 0
        playbackSessionID = nil
        isHandlingCompletion = false
        
        repetitionTimer?.invalidate()
        repetitionTimer = nil
        
        completionTimer?.invalidate()
        completionTimer = nil
        
        // Cancel scheduled next repetition
        nextRepetitionWorkItem?.cancel()
        nextRepetitionWorkItem = nil
        
        // Stop interval timer
        stopIntervalTimer()
        
        // Reset counters immediately to prevent race conditions
        currentRepetition = 0
        totalRepetitions = 0
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isPaused = false
            self.isInPlaybackSession = false  // End of playback session
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
        progressTimer = Timer.scheduledTimer(withTimeInterval: Constants.progressUpdateInterval, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.playbackProgress = player.currentTime / player.duration
            }
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    // MARK: - Interval Timer
    
    private func startIntervalTimer(duration: TimeInterval) {
        // Only stop the timer itself, don't reset the state
        intervalTimer?.invalidate()
        intervalTimer = nil
        
        // Starting interval timer
        
        // Set the start time only if not already set (for resume case)
        if intervalStartTime == nil {
            intervalStartTime = Date()
        }
        
        // Create and schedule timer on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.intervalTimer = Timer.scheduledTimer(withTimeInterval: Constants.intervalTimerUpdateInterval, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                guard let startTime = self.intervalStartTime else {
                    // No start time set
                    timer.invalidate()
                    return
                }
                
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / duration, 1.0)
                
                // Interval progress goes from 1.0 to 0.0 (counting down)
                let intervalProg = max(1.0 - progress, 0.0)
                
                // Update on main queue
                DispatchQueue.main.async {
                    self.intervalProgress = intervalProg
                }
                
                // Debug print first time and every 0.5 seconds
                if elapsed < 0.05 || Int(elapsed / Constants.intervalDebugPrintInterval) != Int((elapsed - Constants.intervalTimerUpdateInterval) / Constants.intervalDebugPrintInterval) {
                    // Interval progress update
                }
                
                // Stop timer when interval is complete
                if progress >= 1.0 {
                    timer.invalidate()
                    self.intervalTimer = nil
                    // Interval timer completed
                }
            }
        }
    }
    
    private func stopIntervalTimer() {
        intervalTimer?.invalidate()
        intervalTimer = nil
        intervalStartTime = nil
        
        DispatchQueue.main.async {
            self.isInInterval = false
            self.intervalProgress = 0
        }
    }
    
    // MARK: - Completion Monitor
    
    private func startCompletionMonitor() {
        // Stop any existing completion timer
        completionTimer?.invalidate()
        completionTimer = nil
        
        guard let player = audioPlayer else { 
            return // No audio player to monitor 
        }
        
        // Capture the current session ID
        let sessionID = playbackSessionID
        
        // Set up a timer to check if playback has completed
        // Check slightly after the expected duration
        let checkInterval = player.duration + Constants.completionCheckDelay
        
        // Setting up completion monitor
        
        // Use asyncAfter instead of Timer for more reliable execution
        DispatchQueue.main.asyncAfter(deadline: .now() + checkInterval) { [weak self] in
            guard let self = self else {
                // AudioService was deallocated during playback
                return
            }
            
            // Check if this is still the same playback session
            guard self.playbackSessionID == sessionID else {
                // Ignoring completion check from old session
                return
            }
            
            // Completion check
            
            // Only handle completion if player exists and is not playing
            if let player = self.audioPlayer, !player.isPlaying {
                // Playback completed - handling completion
                self.handlePlaybackCompletion()
            }
        }
    }
    
    private func handlePlaybackCompletion() {
        // Prevent double handling
        guard !isHandlingCompletion else {
            // Already handling completion, skipping duplicate call
            return
        }
        
        guard let script = currentScript else {
            stopPlayback()
            return
        }
        
        // Mark that we're handling completion
        isHandlingCompletion = true
        
        // Handling playback completion
        
        // Cancel any pending completion timer since we're handling it now
        completionTimer?.invalidate()
        completionTimer = nil
        
        // Check if we have more repetitions to play
        if currentRepetition < totalRepetitions {
            // We need to play more repetitions
            currentRepetition += 1
            playbackProgress = 0
            
            // Will play next repetition after interval
            
            // Stop the progress timer during interval
            stopProgressTimer()
            
            // Start interval countdown - keep playing state
            // Update on main queue to ensure UI updates
            DispatchQueue.main.async {
                self.isInInterval = true
                self.intervalProgress = 1.0  // Start at full
                self.playbackProgress = 0  // Reset playback progress
                // Don't change isPlaying - let it stay true
                // Interval started
                
                // Start interval progress timer AFTER setting the state
                self.startIntervalTimer(duration: script.intervalSeconds)
            }
            
            // Play next repetition after interval
            // Cancel any existing work item first
            self.nextRepetitionWorkItem?.cancel()
            
            // Create new work item for next repetition
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, !self.isPaused else { return }
                self.playNextRepetition()
            }
            self.nextRepetitionWorkItem = workItem
            
            DispatchQueue.main.asyncAfter(deadline: .now() + script.intervalSeconds, execute: workItem)
        } else {
            // All repetitions completed
            // All repetitions completed
            stopPlayback()
        }
    }
    
    private func playNextRepetition() {
        // Playing next repetition
        
        // Stop interval timer and reset interval state
        stopIntervalTimer()
        intervalPausedTime = 0
        
        // Reset the handling flag for the next playback
        isHandlingCompletion = false
        
        // Make sure we still have the player
        guard let player = audioPlayer else {
            // Audio player is nil, cannot continue repetitions
            stopPlayback()
            return
        }
        
        // Reset and play
        player.currentTime = 0
        player.prepareToPlay()
        
        if player.play() {
            // Successfully started repetition
            DispatchQueue.main.async {
                self.isPlaying = true
                self.isPaused = false
                self.isInInterval = false
            }
            startProgressTimer()
            startCompletionMonitor()
        } else {
            // Failed to play repetition
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
        
        // Clear recording properties to trigger UI update
        script.audioFilePath = nil
        script.audioDuration = 0
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
        // AVAudioPlayerDelegate: audioPlayerDidFinishPlaying called
        
        // Ignore if we don't have an active session (old delegate callback)
        guard playbackSessionID != nil else {
            // Ignoring delegate callback - no active session
            return
        }
        
        // Cancel the completion timer since delegate fired
        completionTimer?.invalidate()
        completionTimer = nil
        
        // Use the common completion handler
        handlePlaybackCompletion()
    }
}