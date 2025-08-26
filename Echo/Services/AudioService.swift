import AVFoundation
import Combine
import SwiftUI

// MARK: - Error Types

enum AudioServiceError: LocalizedError {
    case privateModeActive
    case recordingFailed
    case playbackFailed
    case noRecording
    case permissionDenied
    case invalidScript
    
    var errorDescription: String? {
        switch self {
        case .privateModeActive:
            return "Please connect earphones to play audio"
        case .recordingFailed:
            return "Failed to record audio"
        case .playbackFailed:
            return "Failed to play audio"
        case .noRecording:
            return "No recording available"
        case .permissionDenied:
            return "Microphone permission denied"
        case .invalidScript:
            return "Script is no longer available"
        }
    }
}

// MARK: - AudioService (Legacy Compatibility Wrapper)

/// Legacy AudioService class that wraps AudioCoordinator for backward compatibility
/// This allows existing code and tests to continue working without modification
class AudioService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AudioService()
    
    // MARK: - Published Properties (Forwarded from AudioCoordinator)
    
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var isInPlaybackSession = false
    @Published var currentPlayingScriptId: UUID?
    @Published var playbackProgress: Double = 0
    @Published var privateModeActive = false
    @Published var currentRepetition: Int = 0
    @Published var totalRepetitions: Int = 0
    @Published var isInInterval = false
    @Published var intervalProgress: Double = 0
    
    // MARK: - Private Properties
    
    private let coordinator = AudioCoordinator.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        bindToCoordinator()
    }
    
    // MARK: - Binding
    
    private func bindToCoordinator() {
        // Bind all published properties to coordinator
        coordinator.$isRecording
            .assign(to: &$isRecording)
        
        coordinator.$isPlaying
            .assign(to: &$isPlaying)
        
        coordinator.$isPaused
            .assign(to: &$isPaused)
        
        coordinator.$isInPlaybackSession
            .assign(to: &$isInPlaybackSession)
        
        coordinator.$currentPlayingScriptId
            .assign(to: &$currentPlayingScriptId)
        
        coordinator.$playbackProgress
            .assign(to: &$playbackProgress)
        
        coordinator.$privateModeActive
            .assign(to: &$privateModeActive)
        
        coordinator.$currentRepetition
            .assign(to: &$currentRepetition)
        
        coordinator.$totalRepetitions
            .assign(to: &$totalRepetitions)
        
        coordinator.$isInInterval
            .assign(to: &$isInInterval)
        
        coordinator.$intervalProgress
            .assign(to: &$intervalProgress)
    }
    
    // MARK: - Recording Methods
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        coordinator.requestMicrophonePermission(completion: completion)
    }
    
    func startRecording(for script: SelftalkScript) throws {
        try coordinator.startRecording(for: script)
    }
    
    func stopRecording() {
        coordinator.stopRecording()
    }
    
    // MARK: - Playback Methods
    
    func play(script: SelftalkScript) throws {
        try coordinator.play(script: script)
    }
    
    func pausePlayback() {
        coordinator.pausePlayback()
    }
    
    func resumePlayback() {
        coordinator.resumePlayback()
    }
    
    func stopPlayback() {
        coordinator.stopPlayback()
    }
    
    func setPlaybackSpeed(_ speed: Float) {
        coordinator.setPlaybackSpeed(speed)
    }
    
    // MARK: - File Management Methods
    
    func deleteRecording(for script: SelftalkScript) {
        coordinator.deleteRecording(for: script)
    }
    
    func checkPrivateMode() {
        coordinator.checkPrivateMode()
    }
}