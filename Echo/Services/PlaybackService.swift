import AVFoundation
import Combine

/// Manages audio playback with repetitions and intervals
final class PlaybackService: NSObject {
    
    // MARK: - State Change Callbacks
    
    var onPlayingStateChange: ((Bool) -> Void)?
    var onPausedStateChange: ((Bool) -> Void)?
    var onPlaybackSessionChange: ((Bool) -> Void)?
    var onCurrentScriptIdChange: ((UUID?) -> Void)?
    var onProgressUpdate: ((Double) -> Void)?
    var onRepetitionUpdate: ((Int, Int) -> Void)?  // current, total
    var onIntervalStateChange: ((Bool) -> Void)?
    var onIntervalProgressUpdate: ((Double) -> Void)?
    
    // MARK: - Internal State (not published)
    
    private(set) var isPlaying = false {
        didSet { onPlayingStateChange?(isPlaying) }
    }
    
    private(set) var isPaused = false {
        didSet { onPausedStateChange?(isPaused) }
    }
    
    private(set) var isInPlaybackSession = false {
        didSet { onPlaybackSessionChange?(isInPlaybackSession) }
    }
    
    private(set) var currentPlayingScriptId: UUID? {
        didSet { onCurrentScriptIdChange?(currentPlayingScriptId) }
    }
    
    private(set) var playbackProgress: Double = 0 {
        didSet { onProgressUpdate?(playbackProgress) }
    }
    
    private(set) var currentRepetition: Int = 0 {
        didSet { onRepetitionUpdate?(currentRepetition, totalRepetitions) }
    }
    
    private(set) var totalRepetitions: Int = 0 {
        didSet { onRepetitionUpdate?(currentRepetition, totalRepetitions) }
    }
    
    private(set) var isInInterval = false {
        didSet { onIntervalStateChange?(isInInterval) }
    }
    
    private(set) var intervalProgress: Double = 0 {
        didSet { onIntervalProgressUpdate?(intervalProgress) }
    }
    
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
        print("\n🎵 PlaybackService.startPlayback() called")
        print("   Script ID: \(scriptId)")
        print("   Repetitions: \(repetitions), Interval: \(intervalSeconds)s")
        print("   Private mode enabled: \(privateModeEnabled), active: \(sessionManager.privateModeActive)")
        print("   Current audio session state: \(sessionManager.currentState.rawValue)")
        
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
        
        // Auto-stop any current playback (different script or playing state)
        // This ensures only one script plays at a time
        if isPlaying || isPaused || isInPlaybackSession {
            print("PlaybackService: Auto-stopping previous playback")
            stopPlayback()
        }
        
        // Configure session for playback (no need to check result)
        sessionManager.configureForPlayback()
        
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
            
            // Initialize new playback session
            // Previous playback was already stopped above if needed
            playbackSessionID = UUID()
            pausedTime = 0
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentRepetition = 1
                self.totalRepetitions = repetitions
            }
            
            let playStarted = audioPlayer?.play() ?? false
            print("   AVAudioPlayer.play() returned: \(playStarted)")
            
            if !playStarted {
                print("   🔄 Failed to start playback - attempting recovery")
                
                // Try once more after re-preparing
                audioPlayer?.prepareToPlay()
                Thread.sleep(forTimeInterval: 0.2)
                
                let recoveryPlayStarted = audioPlayer?.play() ?? false
                print("   Recovery attempt play() returned: \(recoveryPlayStarted)")
                
                guard recoveryPlayStarted else {
                    print("   ❌ Failed to start playback after recovery attempt")
                    // Failed to start playback, reset state to idle for future attempts
                    sessionManager.transitionTo(.idle)
                    
                    // Clean up
                    audioPlayer = nil
                    playbackSessionID = nil
                    
                    throw AudioServiceError.playbackFailed
                }
                
                // If we reach here, recovery succeeded
                print("   ✅ Playback recovered successfully")
            } else {
                print("   ✅ Playback started successfully")
            }
            
            // Successfully started playing
            // Direct transition from Idle to Playing (no preparingToPlay needed)
            sessionManager.transitionTo(.playing)
            print("   Transitioned to Playing state")
            
            DispatchQueue.main.async {
                self.isPlaying = true
                self.isPaused = false
                self.isInPlaybackSession = true
                self.currentPlayingScriptId = scriptId
            }
            
            startProgressTimer()
            startCompletionMonitor()
            
        } catch {
            print("   ❌ Error creating audio player: \(error)")
            print("   Error code: \((error as NSError).code)")
            print("   Resetting session to idle state")
            // Ensure we're back in idle state after any failure
            sessionManager.transitionTo(.idle)
            
            // Clean up
            audioPlayer = nil
            playbackSessionID = nil
            currentScriptRepetitions = 1
            currentScriptIntervalSeconds = 3
            
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
        // Guard against multiple calls
        guard playbackSessionID != nil else { return }
        
        // Invalidate session first to prevent any pending operations
        let oldSessionID = playbackSessionID
        playbackSessionID = nil
        
        // Handle state transition based on current state
        switch sessionManager.currentState {
        case .playing, .paused:
            // Normal playback stopping: go through transitioning state
            sessionManager.transitionTo(.transitioning)
        case .idle, .transitioning:
            // Already idle or transitioning, no action needed
            break
        default:
            // Any other state, try to reset to idle
            sessionManager.transitionTo(.idle)
        }
        
        // Clean up resources
        audioPlayer?.stop()
        audioPlayer = nil
        
        pausedTime = 0
        intervalPausedTime = 0
        isHandlingCompletion = false
        intervalStartTime = nil
        
        // Cancel all timers
        completionTimer?.invalidate()
        completionTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil
        intervalTimer?.invalidate()
        intervalTimer = nil
        
        // Cancel pending work
        nextRepetitionWorkItem?.cancel()
        nextRepetitionWorkItem = nil
        
        // Final transition to idle (only if we were transitioning)
        if sessionManager.currentState == .transitioning {
            sessionManager.transitionTo(.idle)
        }
        
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
            // Track single playback completion (not full script completion yet)
            if let scriptId = currentPlayingScriptId {
                HabitMetrics.playbackCompleted(scriptId: scriptId, completionRate: 1.0, isFirstPlayback: currentRepetition == 1)
            }
            
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
            // Track final playback completion and script repetition completion
            if let scriptId = currentPlayingScriptId {
                HabitMetrics.playbackCompleted(scriptId: scriptId, completionRate: 1.0, isFirstPlayback: false)
                HabitMetrics.scriptRepeated(scriptId: scriptId, completedRepetitions: totalRepetitions, totalRepetitions: totalRepetitions)
            }
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