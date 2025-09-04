import Foundation

/// Helper class for file operations with retry logic and comprehensive error handling
final class FileOperationHelper {
    
    // MARK: - Constants
    
    private enum Constants {
        static let maxRetryAttempts = 3
        static let retryDelay: TimeInterval = 0.5
        static let minRequiredDiskSpace: Int64 = 10 * 1024 * 1024 // 10MB minimum
    }
    
    // MARK: - Disk Space Check
    
    static func checkAvailableDiskSpace() throws {
        let fileManager = FileManager.default
        
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw AudioServiceError.directoryCreationFailed
        }
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: documentDirectory.path)
            if let freeSpace = attributes[.systemFreeSize] as? NSNumber {
                let freeSpaceInBytes = freeSpace.int64Value
                if freeSpaceInBytes < Constants.minRequiredDiskSpace {
                    throw AudioServiceError.insufficientDiskSpace
                }
            }
        } catch {
            // If we can't check, continue anyway
            #if DEBUG
            print("Warning: Could not check disk space: \(error)")
            #endif
        }
    }
    
    // MARK: - File Operations with Retry
    
    /// Copy file with retry logic
    static func copyFile(from source: URL, to destination: URL, maxRetries: Int = Constants.maxRetryAttempts) throws {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                // Remove destination if exists
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                
                // Try to copy
                try FileManager.default.copyItem(at: source, to: destination)
                return // Success
                
            } catch CocoaError.fileWriteOutOfSpace {
                throw AudioServiceError.insufficientDiskSpace
            } catch CocoaError.fileWriteNoPermission {
                throw AudioServiceError.filePermissionDenied
            } catch {
                lastError = error
                
                // If not the last attempt, wait and retry
                if attempt < maxRetries - 1 {
                    Thread.sleep(forTimeInterval: Constants.retryDelay)
                }
            }
        }
        
        // All retries failed
        throw AudioServiceError.fileCopyFailed(lastError?.localizedDescription ?? "Unknown error")
    }
    
    /// Move file with retry logic
    static func moveFile(from source: URL, to destination: URL, maxRetries: Int = Constants.maxRetryAttempts) throws {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                // Remove destination if exists
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                
                // Try to move
                try FileManager.default.moveItem(at: source, to: destination)
                return // Success
                
            } catch CocoaError.fileWriteOutOfSpace {
                throw AudioServiceError.insufficientDiskSpace
            } catch CocoaError.fileWriteNoPermission {
                throw AudioServiceError.filePermissionDenied
            } catch {
                lastError = error
                
                // If not the last attempt, wait and retry
                if attempt < maxRetries - 1 {
                    Thread.sleep(forTimeInterval: Constants.retryDelay)
                }
            }
        }
        
        // All retries failed
        throw AudioServiceError.fileMoveFailed(lastError?.localizedDescription ?? "Unknown error")
    }
    
    /// Delete file with retry logic
    static func deleteFile(at url: URL, maxRetries: Int = Constants.maxRetryAttempts) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return // File doesn't exist, nothing to delete
        }
        
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                try FileManager.default.removeItem(at: url)
                return // Success
                
            } catch CocoaError.fileWriteNoPermission {
                throw AudioServiceError.filePermissionDenied
            } catch {
                lastError = error
                
                // If not the last attempt, wait and retry
                if attempt < maxRetries - 1 {
                    Thread.sleep(forTimeInterval: Constants.retryDelay)
                }
            }
        }
        
        // All retries failed
        throw AudioServiceError.fileDeleteFailed(lastError?.localizedDescription ?? "Unknown error")
    }
    
    /// Create directory with retry logic
    static func createDirectory(at url: URL, maxRetries: Int = Constants.maxRetryAttempts) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else {
            return // Directory already exists
        }
        
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                return // Success
                
            } catch CocoaError.fileWriteOutOfSpace {
                throw AudioServiceError.insufficientDiskSpace
            } catch CocoaError.fileWriteNoPermission {
                throw AudioServiceError.filePermissionDenied
            } catch {
                lastError = error
                
                // If not the last attempt, wait and retry
                if attempt < maxRetries - 1 {
                    Thread.sleep(forTimeInterval: Constants.retryDelay)
                }
            }
        }
        
        // All retries failed - throw the last error or a generic error
        throw lastError ?? AudioServiceError.directoryCreationFailed
    }
    
    /// Validate audio file integrity
    static func validateAudioFile(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioServiceError.fileNotFound(url.lastPathComponent)
        }
        
        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64, fileSize == 0 {
                throw AudioServiceError.fileCorrupted(url.lastPathComponent)
            }
        } catch {
            throw AudioServiceError.fileCorrupted(url.lastPathComponent)
        }
        
        // Try to read the file header to ensure it's a valid audio file
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            let headerData = fileHandle.readData(ofLength: 4)
            fileHandle.closeFile()
            
            if headerData.count < 4 {
                throw AudioServiceError.fileCorrupted(url.lastPathComponent)
            }
        } catch {
            throw AudioServiceError.fileCorrupted(url.lastPathComponent)
        }
    }
    
    // MARK: - Async Versions for Background Operations
    
    /// Copy file asynchronously with retry logic
    static func copyFileAsync(from source: URL, to destination: URL, maxRetries: Int = Constants.maxRetryAttempts) async throws {
        try await Task.detached(priority: .background) {
            try copyFile(from: source, to: destination, maxRetries: maxRetries)
        }.value
    }
    
    /// Move file asynchronously with retry logic
    static func moveFileAsync(from source: URL, to destination: URL, maxRetries: Int = Constants.maxRetryAttempts) async throws {
        try await Task.detached(priority: .background) {
            try moveFile(from: source, to: destination, maxRetries: maxRetries)
        }.value
    }
    
    /// Delete file asynchronously with retry logic
    static func deleteFileAsync(at url: URL, maxRetries: Int = Constants.maxRetryAttempts) async throws {
        try await Task.detached(priority: .background) {
            try deleteFile(at: url, maxRetries: maxRetries)
        }.value
    }
    
    /// Create directory asynchronously with retry logic
    static func createDirectoryAsync(at url: URL, maxRetries: Int = Constants.maxRetryAttempts) async throws {
        try await Task.detached(priority: .background) {
            try createDirectory(at: url, maxRetries: maxRetries)
        }.value
    }
    
    /// Validate audio file asynchronously
    static func validateAudioFileAsync(at url: URL) async throws {
        try await Task.detached(priority: .background) {
            try validateAudioFile(at: url)
        }.value
    }
    
    /// Check available disk space asynchronously
    static func checkAvailableDiskSpaceAsync() async throws {
        try await Task.detached(priority: .background) {
            try checkAvailableDiskSpace()
        }.value
    }
}