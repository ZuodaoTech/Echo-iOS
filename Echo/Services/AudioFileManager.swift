import Foundation
import AVFoundation

/// Manages audio file operations for recordings
final class AudioFileManager {
    
    // MARK: - Properties
    
    private let recordingsDirectory: URL
    
    // MARK: - Security Constants
    
    private enum SecurityConstants {
        static let maxPathLength = 255
        static let allowedFileExtensions: Set<String> = ["m4a", "wav", "aac"]
        static let forbiddenPathComponents: Set<String> = ["..", "~", "/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
        static let maxFilenameLength = 100
    }
    
    // MARK: - Initialization
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.recordingsDirectory = documentsPath.appendingPathComponent("Recordings")
        do {
            try createRecordingsDirectory()
        } catch {
            SecureLogger.error("AudioFileManager: Failed to create recordings directory: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Path Validation
    
    /// Validates a file path for security vulnerabilities
    private func validatePath(_ path: String) throws {
        // Check path length
        guard path.count <= SecurityConstants.maxPathLength else {
            throw AudioServiceError.invalidPath("Path too long")
        }
        
        // Check for forbidden components
        for forbidden in SecurityConstants.forbiddenPathComponents {
            if path.contains(forbidden) {
                throw AudioServiceError.invalidPath("Path contains forbidden characters: \(forbidden)")
            }
        }
        
        // Check for path traversal attempts
        let normalizedPath = (path as NSString).standardizingPath
        if normalizedPath.contains("..") || normalizedPath.hasPrefix("/") {
            throw AudioServiceError.invalidPath("Path traversal detected")
        }
    }
    
    /// Validates a UUID and returns sanitized filename
    private func validateAndSanitizeFilename(for scriptId: UUID, extension fileExtension: String) throws -> String {
        let uuidString = scriptId.uuidString
        
        // Validate UUID format (additional safety)
        let uuidRegex = try NSRegularExpression(pattern: "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$")
        let range = NSRange(location: 0, length: uuidString.count)
        guard uuidRegex.firstMatch(in: uuidString, options: [], range: range) != nil else {
            throw AudioServiceError.invalidPath("Invalid UUID format")
        }
        
        // Validate file extension
        guard SecurityConstants.allowedFileExtensions.contains(fileExtension.lowercased()) else {
            throw AudioServiceError.invalidPath("Unsupported file extension: \(fileExtension)")
        }
        
        let filename = "\(uuidString).\(fileExtension)"
        
        // Final length check
        guard filename.count <= SecurityConstants.maxFilenameLength else {
            throw AudioServiceError.invalidPath("Filename too long")
        }
        
        return filename
    }
    
    /// Validates that a URL is within the allowed recordings directory
    private func validateURLIsInRecordingsDirectory(_ url: URL) throws {
        let recordingsPath = recordingsDirectory.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        
        guard filePath.hasPrefix(recordingsPath + "/") || filePath == recordingsPath else {
            throw AudioServiceError.invalidPath("File path outside allowed directory")
        }
    }
    
    // MARK: - Public Methods
    
    /// Get the audio file URL for a script with path validation
    func audioURL(for scriptId: UUID) -> URL {
        do {
            let filename = try validateAndSanitizeFilename(for: scriptId, extension: "m4a")
            let url = recordingsDirectory.appendingPathComponent(filename)
            try validateURLIsInRecordingsDirectory(url)
            return url
        } catch {
            // Log security issue and return safe fallback
            SecureLogger.security("Path validation failed for audio file: \(error.localizedDescription)")
            // Return a safe, sanitized path as fallback
            let safeFilename = "audio_\(abs(scriptId.hashValue)).m4a"
            return recordingsDirectory.appendingPathComponent(safeFilename)
        }
    }
    
    /// Get the URL for the original unprocessed recording (for transcription) with path validation
    func originalAudioURL(for scriptId: UUID) -> URL {
        do {
            let filename = try validateAndSanitizeFilename(for: scriptId, extension: "m4a")
            let originalFilename = filename.replacingOccurrences(of: ".m4a", with: "_original.m4a")
            let url = recordingsDirectory.appendingPathComponent(originalFilename)
            try validateURLIsInRecordingsDirectory(url)
            return url
        } catch {
            // Log security issue and return safe fallback
            SecureLogger.security("Path validation failed for original audio file: \(error.localizedDescription)")
            // Return a safe, sanitized path as fallback
            let safeFilename = "audio_\(abs(scriptId.hashValue))_original.m4a"
            return recordingsDirectory.appendingPathComponent(safeFilename)
        }
    }
    
    /// Check if audio file exists for a script
    func audioFileExists(for scriptId: UUID) -> Bool {
        let url = audioURL(for: scriptId)
        let exists = FileManager.default.fileExists(atPath: url.path)
        
        if exists {
            // Also check if file has non-zero size (not corrupted/incomplete)
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let fileSize = attributes[.size] as? Int64 {
                if fileSize == 0 {
                    SecureLogger.warning("AudioFileManager: Audio file exists but has zero size")
                    return false
                }
            }
        }
        
        return exists
    }
    
    /// Check if audio file exists for a script (async version)
    func audioFileExistsAsync(for scriptId: UUID) async -> Bool {
        await Task.detached(priority: .background) {
            FileManager.default.fileExists(atPath: self.audioURL(for: scriptId).path)
        }.value
    }
    
    /// Delete recording for a script with proper error handling
    func deleteRecording(for scriptId: UUID) throws {
        // Delete the processed audio file
        let url = audioURL(for: scriptId)
        do {
            try FileOperationHelper.deleteFile(at: url)
        } catch {
            SecureLogger.warning("AudioFileManager: Failed to delete processed audio: \(error.localizedDescription)")
            // Continue to try deleting original file even if processed file fails
        }
        
        // Delete the original audio file (used for transcription)
        let originalUrl = originalAudioURL(for: scriptId)
        do {
            try FileOperationHelper.deleteFile(at: originalUrl)
        } catch {
            SecureLogger.warning("AudioFileManager: Failed to delete original audio: \(error.localizedDescription)")
            // Don't throw here as the files might already be deleted
        }
    }
    
    /// Delete recording for a script asynchronously
    func deleteRecordingAsync(for scriptId: UUID) async throws {
        // Delete the processed audio file
        let url = audioURL(for: scriptId)
        do {
            try await FileOperationHelper.deleteFileAsync(at: url)
        } catch {
            SecureLogger.warning("AudioFileManager: Failed to delete processed audio: \(error.localizedDescription)")
        }
        
        // Delete the original audio file
        let originalUrl = originalAudioURL(for: scriptId)
        do {
            try await FileOperationHelper.deleteFileAsync(at: originalUrl)
        } catch {
            SecureLogger.warning("AudioFileManager: Failed to delete original audio: \(error.localizedDescription)")
        }
    }
    
    /// Get audio duration for a recording
    func getAudioDuration(for scriptId: UUID) -> TimeInterval? {
        let url = audioURL(for: scriptId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        
        // Try AVAsset first (more reliable for certain formats)
        let asset = AVAsset(url: url)
        let assetDuration = CMTimeGetSeconds(asset.duration)
        if assetDuration > 0 && !assetDuration.isNaN && !assetDuration.isInfinite {
            return assetDuration
        }
        
        // Fallback to AVAudioPlayer
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay() // Ensure file is loaded
            let duration = player.duration
            if duration > 0 && !duration.isNaN && !duration.isInfinite {
                return duration
            }
        } catch {
            SecureLogger.debug("Failed to get duration with AVAudioPlayer: \(error.localizedDescription)")
        }
        
        // If both methods fail, return nil
        return nil
    }
    
    /// Get audio duration asynchronously
    func getAudioDurationAsync(for scriptId: UUID) async -> TimeInterval? {
        await Task.detached(priority: .background) { [self] in
            return getAudioDuration(for: scriptId)
        }.value
    }
    
    /// Get all recording URLs with proper error handling
    func getAllRecordingURLs() -> [URL] {
        do {
            // First ensure directory exists
            try createRecordingsDirectory()
            
            let urls = try FileManager.default.contentsOfDirectory(
                at: recordingsDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: .skipsHiddenFiles
            )
            return urls.filter { $0.pathExtension == "m4a" }
        } catch {
            SecureLogger.error("AudioFileManager: Failed to get recording URLs: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Calculate total storage used by recordings
    func totalRecordingsSize() -> Int64 {
        let urls = getAllRecordingURLs()
        var totalSize: Int64 = 0
        
        for url in urls {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }
        
        return totalSize
    }
    
    /// Validate if an audio file is accessible and not corrupted
    func validateAudioFile(for scriptId: UUID) throws {
        let url = audioURL(for: scriptId)
        try FileOperationHelper.validateAudioFile(at: url)
    }
    
    // MARK: - Private Methods
    
    private func createRecordingsDirectory() throws {
        try FileOperationHelper.createDirectory(at: recordingsDirectory)
    }
}