import Foundation

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
    case invalidState(String)
    
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
        case .invalidState(let message):
            return String(format: NSLocalizedString("error.invalid_state", comment: "Invalid audio state: %@"), message)
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