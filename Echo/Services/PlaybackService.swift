import AVFoundation
import Combine

/// Manages audio playback with repetitions and intervals
final class PlaybackService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var isInPlaybackSession = false
    @Published var currentPlayingScriptId: UUID?
    @Published var playbackProgress: Double = 0
    @Published var currentRepetition: Int = 0
    @Published var totalRepetitions: Int = 0
    @Published var isInInterval = false
    @Published var intervalProgress: Double = 0
    
    // MARK: - Properties
    
    private var audioPlayer: AVAudioPlayer?
    private let fileManager: AudioFileManager
    private let sessionManager: AudioSessionManager
    
    private var progressTimer: Timer?
    private var intervalTimer: Timer?
    private var completionTimer: Timer?
    
    private var playbackSessionID: UUID?
    private var pausedTime: TimeInterval = 0
    private var intervalStartTime: Date?
    private var intervalPausedTime: TimeInterval = 0
    private var nextRepetitionWorkItem: DispatchWorkItem?
    private var isHandlingCompletion = false
    
    private var currentScriptRepetitions: Int = 1
    private var currentScriptIntervalSeconds: TimeInterval = 3
    
    // MARK: - Constants
    
    private enum Constants {
        static let progressUpdateInterval: TimeInterval = 0.1
        static let intervalTimerUpdateInterval: TimeInterval = 0.02
        static let completionCheckDelay: TimeInterval = 0.1
    }
    
    // MARK: - Initialization
    
    init(fileManager: AudioFileManager, sessionManager: AudioSessionManager) {
        self.fileManager = fileManager
        self.sessionManager = sessionManager
        super.init()
    }
    
    deinit {
        // Clean up all timers
        progressTimer?.invalidate()
        progressTimer = nil
        
        intervalTimer?.invalidate()
        intervalTimer = nil
        
        completionTimer?.invalidate()
        completionTimer = nil
        
        // Cancel any pending work items
        nextRepetitionWorkItem?.cancel()
        nextRepetitionWorkItem = nil
        
        // Clean up audio player
        audioPlayer?.stop()
        audioPlayer = nil
        
        print("PlaybackService: Deinitialized - all resources cleaned up")
    }
    
    // MARK: - Public Methods
    
    /// Start playback for a script
    func startPlayback(
        scriptId: UUID,
        repetitions: Int,
        intervalSeconds: TimeInterval,
        privateModeEnabled: Bool
    ) throws {
        print("PlaybackService: Starting playback for script \(scriptId)")
        print("Private mode enabled: \(privateModeEnabled), active: \(sessionManager.privateModeActive)")
        
        // Check private mode
        if privateModeEnabled && sessionManager.privateModeActive {
            print("PlaybackService: Blocked by private mode")
            throw AudioServiceError.privateModeActive
        }
        
        // Check if file exists
        guard fileManager.audioFileExists(for: scriptId) else {
            print("PlaybackService: No recording file found")
            throw AudioServiceError.noRecording
        }
        print("PlaybackService: Audio file exists")
        
        // If paused on same script, resume instead
        if isPaused && currentPlayingScriptId == scriptId {
            resumePlayback()
            return
        }
        
        // Stop any current playback
        stopPlayback()
        
        // Configure session for playback
        try sessionManager.configureForPlayback()
        
        let audioURL = fileManager.audioURL(for: scriptId)
        
        do {
            print("PlaybackService: Creating AVAudioPlayer with URL: \(audioURL)")
            
            // First, validate the file
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            print("PlaybackService: File size: \(fileSize) bytes")
            
            // Try using AVAsset to get duration first (more reliable)
            let asset = AVAsset(url: audioURL)
            let duration = CMTimeGetSeconds(asset.duration)
            print("PlaybackService: AVAsset duration: \(duration)s")
            
            // Create the player
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            
            // Important: Call prepareToPlay and wait a moment for the file to be ready
            let prepared = audioPlayer?.prepareToPlay() ?? false
            print("PlaybackService: Prepare to play: \(prepared)")
            
            audioPlayer?.enableRate = true
            
            // Add a small delay to ensure file is ready
            Thread.sleep(forTimeInterval: 0.1)
            
            let playerDuration = audioPlayer?.duration ?? 0
            print("PlaybackService: Player created, duration: \(playerDuration)")
            
            // If duration is still 0, the file might be corrupted or incompatible
            if playerDuration <= 0 && duration <= 0 {
                print("PlaybackService: Warning - Audio file appears to have no duration")
                // Try to play anyway, some files might still work
            }
            
            // Store script parameters
            currentScriptRepetitions = repetitions
            currentScriptIntervalSeconds = intervalSeconds
            
            // Cancel any previous session operations before starting new one
            if playbackSessionID != nil {
                stopPlayback()
            }
            
            // Initialize new playback session
            playbackSessionID = UUID()
            pausedTime = 0
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentRepetition = 1
                self.totalRepetitions = repetitions
            }
            
            if audioPlayer?.play() != true {
                print("PlaybackService: Failed to start playback - attempting recovery")
                
                // Try once more after re-preparing
                audioPlayer?.prepareToPlay()
                Thread.sleep(forTimeInterval: 0.2)
                
                guard audioPlayer?.play() == true else {
                    print("PlaybackService: Failed to start playback after recovery attempt")
                    // Failed to start playback, reset state
                    sessionManager.transitionTo(.idle)
                    throw AudioServiceError.playbackFailed
                }
                
                // If we reach here, recovery succeeded
                print("PlaybackService: Playback recovered successfully")
            } else {
                print("PlaybackService: Playback started successfully")
            }
            
            // Successfully started playing
            sessionManager.transitionTo(.playing)
            
            DispatchQueue.main.async {
                self.isPlaying = true
                self.isPaused = false
                self.isInPlaybackSession = true
                self.currentPlayingScriptId = scriptId
            }
            
            startProgressTimer()
            startCompletionMonitor()
            
        } catch {
            throw AudioServiceError.playbackFailed
        }
    }
    
    /// Pause current playback
    func pausePlayback() {
        guard isInPlaybackSession else { return }
        
        // Transition to paused state
        sessionManager.transitionTo(.paused)
        
        if isInInterval {
            // Pausing during interval
            if let startTime = intervalStartTime {
                intervalPausedTime = Date().timeIntervalSince(startTime)
            }
            intervalTimer?.invalidate()
            intervalTimer = nil
            intervalStartTime = nil
            
            nextRepetitionWorkItem?.cancel()
            nextRepetitionWorkItem = nil
        } else if let player = audioPlayer, player.isPlaying {
            // Pause audio playback
            player.pause()
            pausedTime = player.currentTime
            
            completionTimer?.invalidate()
            completionTimer = nil
            
            stopProgressTimer()
        }
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isPaused = true
        }
    }
    
    /// Resume paused playback
    func resumePlayback() {
        guard isPaused && isInPlaybackSession else { return }
        
        // Transition back to playing state
        sessionManager.transitionTo(.playing)
        
        if isInInterval {
            resumeInterval()
        } else if let player = audioPlayer {
            player.currentTime = pausedTime
            player.play()
            
            DispatchQueue.main.async {
                self.isPlaying = true
                self.isPaused = false
            }
            
            startProgressTimer()
            
            // Restart completion monitor
            let remainingDuration = player.duration - pausedTime + Constants.completionCheckDelay
            completionTimer = Timer.scheduledTimer(withTimeInterval: remainingDuration, repeats: false) { [weak self] _ in
                self?.checkPlaybackCompletion()
            }
        }
    }
    
    /// Stop playback completely
    func stopPlayback() {
        // Transition to transitioning, then idle
        sessionManager.transitionTo(.transitioning)
        
        // Invalidate current session to cancel all orphaned operations
        let oldSessionID = playbackSessionID
        playbackSessionID = nil  // Immediately invalidate to prevent any pending operations
        
        // Stop audio player
        audioPlayer?.stop()
        audioPlayer = nil
        
        // Reset all state
        pausedTime = 0
        intervalPausedTime = 0
        isHandlingCompletion = false
        intervalStartTime = nil
        
        // Cancel all timers and work items
        completionTimer?.invalidate()
        completionTimer = nil
        
        progressTimer?.invalidate()
        progressTimer = nil
        
        intervalTimer?.invalidate()
        intervalTimer = nil
        
        // Cancel any pending repetition work
        if let workItem = nextRepetitionWorkItem {
            workItem.cancel()
            nextRepetitionWorkItem = nil
        }
        
        // Transition to idle after cleanup
        sessionManager.transitionTo(.idle)
        
        // Update UI state on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Double-check session wasn't restarted
            if self.playbackSessionID != nil && self.playbackSessionID != oldSessionID { return }
            
            self.currentRepetition = 0
            self.totalRepetitions = 0
            self.isPlaying = false
            self.isPaused = false
            self.isInPlaybackSession = false
            self.currentPlayingScriptId = nil
            self.playbackProgress = 0
            self.isInInterval = false
            self.intervalProgress = 0
        }
    }
    
    /// Set playback speed
    func setPlaybackSpeed(_ speed: Float) {
        audioPlayer?.rate = speed
    }
    
    /// Check if currently playing a specific script
    func isPlaying(scriptId: UUID) -> Bool {
        isPlaying && currentPlayingScriptId == scriptId
    }
    
    // MARK: - Private Methods
    
    private func startProgressTimer() {
        stopProgressTimer()
        
        // Capture session ID before timer creation
        let sessionID = playbackSessionID
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: Constants.progressUpdateInterval, repeats: true) { [weak self] _ in
            guard let self = self,
                  let player = self.audioPlayer,
                  self.playbackSessionID == sessionID else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      self.playbackSessionID == sessionID else { return }
                self.playbackProgress = player.currentTime / player.duration
            }
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func startIntervalTimer(duration: TimeInterval) {
        intervalTimer?.invalidate()
        intervalTimer = nil
        
        if intervalStartTime == nil {
            intervalStartTime = Date()
        }
        
        // Capture session ID before async operation
        let sessionID = playbackSessionID
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.playbackSessionID == sessionID else { return }
            
            self.intervalTimer = Timer.scheduledTimer(withTimeInterval: Constants.intervalTimerUpdateInterval, repeats: true) { [weak self] timer in
                guard let self = self,
                      let startTime = self.intervalStartTime,
                      self.playbackSessionID == sessionID else {
                    timer.invalidate()
                    return
                }
                
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / duration, 1.0)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self,
                          self.playbackSessionID == sessionID else { return }
                    self.intervalProgress = max(1.0 - progress, 0.0)
                }
                
                if progress >= 1.0 {
                    timer.invalidate()
                    self.intervalTimer = nil
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
    
    private func startCompletionMonitor() {
        completionTimer?.invalidate()
        completionTimer = nil
        
        guard let player = audioPlayer else { return }
        
        let sessionID = playbackSessionID
        let checkInterval = player.duration + Constants.completionCheckDelay
        
        DispatchQueue.main.asyncAfter(deadline: .now() + checkInterval) { [weak self] in
            guard let self = self,
                  self.playbackSessionID == sessionID else { return }
            self.checkPlaybackCompletion()
        }
    }
    
    private func checkPlaybackCompletion() {
        if let player = audioPlayer, !player.isPlaying {
            handlePlaybackCompletion()
        }
    }
    
    private func handlePlaybackCompletion() {
        guard !isHandlingCompletion else { return }
        isHandlingCompletion = true
        
        // Capture session ID for validation
        let sessionID = playbackSessionID
        guard sessionID != nil else { return }
        
        completionTimer?.invalidate()
        completionTimer = nil
        
        if currentRepetition < totalRepetitions {
            stopProgressTimer()
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      self.playbackSessionID == sessionID else { return }
                self.currentRepetition += 1
                self.playbackProgress = 0
                self.isInInterval = true
                self.intervalProgress = 1.0
            }
            
            startIntervalTimer(duration: currentScriptIntervalSeconds)
            
            nextRepetitionWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self,
                      !self.isPaused,
                      self.playbackSessionID == sessionID else { return }
                self.playNextRepetition()
            }
            nextRepetitionWorkItem = workItem
            
            DispatchQueue.main.asyncAfter(deadline: .now() + currentScriptIntervalSeconds, execute: workItem)
        } else {
            stopPlayback()
        }
    }
    
    private func playNextRepetition() {
        // Validate session before proceeding
        let sessionID = playbackSessionID
        guard sessionID != nil else { return }
        
        stopIntervalTimer()
        intervalPausedTime = 0
        isHandlingCompletion = false
        
        guard let player = audioPlayer,
              playbackSessionID == sessionID else {
            stopPlayback()
            return
        }
        
        player.currentTime = 0
        player.prepareToPlay()
        
        if player.play() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      self.playbackSessionID == sessionID else { return }
                self.isPlaying = true
                self.isPaused = false
                self.isInInterval = false
            }
            startProgressTimer()
            startCompletionMonitor()
        } else {
            stopPlayback()
        }
    }
    
    private func resumeInterval() {
        // Capture session ID for validation
        let sessionID = playbackSessionID
        guard sessionID != nil else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.playbackSessionID == sessionID else { return }
            self.isPaused = false
        }
        
        let remainingInterval = currentScriptIntervalSeconds - intervalPausedTime
        
        intervalStartTime = Date().addingTimeInterval(-intervalPausedTime)
        startIntervalTimer(duration: currentScriptIntervalSeconds)
        
        nextRepetitionWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self,
                  !self.isPaused,
                  self.playbackSessionID == sessionID else { return }
            self.playNextRepetition()
        }
        nextRepetitionWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + remainingInterval, execute: workItem)
    }
}

// MARK: - AVAudioPlayerDelegate

extension PlaybackService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Capture and validate session ID
        let sessionID = playbackSessionID
        guard sessionID != nil else { return }
        
        // Only handle completion if session is still valid
        guard playbackSessionID == sessionID else { return }
        
        completionTimer?.invalidate()
        completionTimer = nil
        
        handlePlaybackCompletion()
    }
}