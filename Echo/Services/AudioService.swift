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
    // File operation errors
    case fileNotFound(String)
    case insufficientDiskSpace
    case filePermissionDenied
    case fileCorrupted(String)
    case directoryCreationFailed
    case fileCopyFailed(String)
    case fileMoveFailed(String)
    case fileDeleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .privateModeActive:
            return NSLocalizedString("error.private_mode", comment: "Please connect earphones to play audio")
        case .recordingFailed:
            return NSLocalizedString("error.recording_failed", comment: "Failed to record audio")
        case .playbackFailed:
            return NSLocalizedString("error.playback_failed", comment: "Failed to play audio")
        case .noRecording:
            return NSLocalizedString("error.no_recording", comment: "No recording available")
        case .permissionDenied:
            return NSLocalizedString("error.permission_denied", comment: "Microphone permission denied")
        case .invalidScript:
            return NSLocalizedString("error.invalid_script", comment: "Script is no longer available")
        // File operation errors
        case .fileNotFound(let filename):
            return String(format: NSLocalizedString("error.file_not_found", comment: "File not found: %@"), filename)
        case .insufficientDiskSpace:
            return NSLocalizedString("error.insufficient_disk_space", comment: "Not enough storage space. Please free up some space and try again.")
        case .filePermissionDenied:
            return NSLocalizedString("error.file_permission_denied", comment: "Permission denied. Unable to access the file.")
        case .fileCorrupted(let filename):
            return String(format: NSLocalizedString("error.file_corrupted", comment: "File is corrupted: %@"), filename)
        case .directoryCreationFailed:
            return NSLocalizedString("error.directory_creation_failed", comment: "Failed to create recordings directory")
        case .fileCopyFailed(let reason):
            return String(format: NSLocalizedString("error.file_copy_failed", comment: "Failed to copy file: %@"), reason)
        case .fileMoveFailed(let reason):
            return String(format: NSLocalizedString("error.file_move_failed", comment: "Failed to move file: %@"), reason)
        case .fileDeleteFailed(let reason):
            return String(format: NSLocalizedString("error.file_delete_failed", comment: "Failed to delete file: %@"), reason)
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .insufficientDiskSpace:
            return NSLocalizedString("error.suggestion.free_space", comment: "Delete some recordings or other files to free up space.")
        case .filePermissionDenied:
            return NSLocalizedString("error.suggestion.restart_app", comment: "Try restarting the app.")
        case .fileCorrupted:
            return NSLocalizedString("error.suggestion.rerecord", comment: "Try recording again.")
        default:
            return nil
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