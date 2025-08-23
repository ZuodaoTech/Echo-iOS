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
        createRecordingsDirectoryIfNeeded()
    }
    
    // MARK: - Public Methods
    
    /// Get the audio file URL for a script
    func audioURL(for scriptId: UUID) -> URL {
        recordingsDirectory.appendingPathComponent("\(scriptId.uuidString).m4a")
    }
    
    /// Check if audio file exists for a script
    func audioFileExists(for scriptId: UUID) -> Bool {
        FileManager.default.fileExists(atPath: audioURL(for: scriptId).path)
    }
    
    /// Delete recording for a script
    func deleteRecording(for scriptId: UUID) throws {
        let url = audioURL(for: scriptId)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    /// Get audio duration for a recording
    func getAudioDuration(for scriptId: UUID) -> TimeInterval? {
        let url = audioURL(for: scriptId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            return player.duration
        } catch {
            return nil
        }
    }
    
    /// Get all recording URLs
    func getAllRecordingURLs() -> [URL] {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: recordingsDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            return urls.filter { $0.pathExtension == "m4a" }
        } catch {
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
    
    // MARK: - Private Methods
    
    private func createRecordingsDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: recordingsDirectory.path) {
            try? FileManager.default.createDirectory(
                at: recordingsDirectory,
                withIntermediateDirectories: true
            )
        }
    }
}