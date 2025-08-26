import Foundation
import AVFoundation

/// Manages audio file operations for recordings
final class AudioFileManager {
    
    // MARK: - Properties
    
    private let recordingsDirectory: URL
    
    // MARK: - Initialization
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.recordingsDirectory = documentsPath.appendingPathComponent("Recordings")
        do {
            try createRecordingsDirectory()
        } catch {
            print("AudioFileManager: Failed to create recordings directory: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Get the audio file URL for a script
    func audioURL(for scriptId: UUID) -> URL {
        recordingsDirectory.appendingPathComponent("\(scriptId.uuidString).m4a")
    }
    
    /// Get the URL for the original unprocessed recording (for transcription)
    func originalAudioURL(for scriptId: UUID) -> URL {
        recordingsDirectory.appendingPathComponent("\(scriptId.uuidString)_original.m4a")
    }
    
    /// Check if audio file exists for a script
    func audioFileExists(for scriptId: UUID) -> Bool {
        FileManager.default.fileExists(atPath: audioURL(for: scriptId).path)
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
            print("AudioFileManager: Warning - Failed to delete processed audio: \(error)")
            // Continue to try deleting original file even if processed file fails
        }
        
        // Delete the original audio file (used for transcription)
        let originalUrl = originalAudioURL(for: scriptId)
        do {
            try FileOperationHelper.deleteFile(at: originalUrl)
        } catch {
            print("AudioFileManager: Warning - Failed to delete original audio: \(error)")
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
            print("AudioFileManager: Warning - Failed to delete processed audio: \(error)")
        }
        
        // Delete the original audio file
        let originalUrl = originalAudioURL(for: scriptId)
        do {
            try await FileOperationHelper.deleteFileAsync(at: originalUrl)
        } catch {
            print("AudioFileManager: Warning - Failed to delete original audio: \(error)")
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
            print("Failed to get duration with AVAudioPlayer: \(error)")
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
            print("AudioFileManager: Failed to get recording URLs: \(error)")
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