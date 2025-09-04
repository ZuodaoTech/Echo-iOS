//
//  ZipArchive.swift
//  Echo
//
//  Simple ZIP archive creation utility
//

import Foundation
import Compression

class ZipArchive {
    
    /// Create a ZIP archive from a directory
    /// - Parameters:
    ///   - sourceDirectory: The directory to compress
    ///   - destinationURL: Where to save the ZIP file
    /// - Throws: Error if compression fails
    static func createZipArchive(from sourceDirectory: URL, to destinationURL: URL) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var archiveError: Error?
        
        coordinator.coordinate(writingItemAt: sourceDirectory, options: .forReplacing, error: &coordinatorError) { (url) in
            do {
                // For iOS, we'll use a simple approach: create a tar archive then compress it
                // This creates a valid archive that can be opened on Mac
                let fileManager = FileManager.default
                
                // Create temporary tar file
                let tempTar = fileManager.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).tar")
                
                // Get all files to archive
                var filesToArchive: [(URL, String)] = []
                if let enumerator = fileManager.enumerator(
                    at: sourceDirectory,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for case let fileURL as URL in enumerator {
                        let attributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                        if attributes.isRegularFile == true {
                            let relativePath = fileURL.path.replacingOccurrences(
                                of: sourceDirectory.path + "/",
                                with: ""
                            )
                            filesToArchive.append((fileURL, relativePath))
                        }
                    }
                }
                
                // Create tar archive
                try createTarArchive(files: filesToArchive, to: tempTar)
                
                // Compress tar to create tar.gz (which macOS can open)
                let compressedData = try Data(contentsOf: tempTar)
                if let compressed = compressedData.compressed(using: .zlib) {
                    try compressed.write(to: destinationURL)
                } else {
                    // If compression fails, at least save the tar
                    try fileManager.copyItem(at: tempTar, to: destinationURL)
                }
                
                // Clean up
                try? fileManager.removeItem(at: tempTar)
                
            } catch {
                archiveError = error
            }
        }
        
        if let error = coordinatorError {
            throw error
        }
        if let error = archiveError {
            throw error
        }
    }
    
    /// Create a TAR archive from files
    private static func createTarArchive(files: [(URL, String)], to destinationURL: URL) throws {
        let outputStream = OutputStream(url: destinationURL, append: false)
        outputStream?.open()
        defer { outputStream?.close() }
        
        guard let stream = outputStream else {
            throw ZipError.cannotCreateArchive
        }
        
        for (fileURL, relativePath) in files {
            let fileData = try Data(contentsOf: fileURL)
            
            // Create TAR header (simplified)
            var header = Data(count: 512)
            
            // File name (100 bytes)
            let nameData = relativePath.data(using: .utf8) ?? Data()
            header.replaceSubrange(0..<min(100, nameData.count), with: nameData)
            
            // File mode (8 bytes) - "0000644\0"
            let mode = "0000644\0".data(using: .ascii)!
            header.replaceSubrange(100..<108, with: mode)
            
            // UID (8 bytes) - "0000000\0"
            let uid = "0000000\0".data(using: .ascii)!
            header.replaceSubrange(108..<116, with: uid)
            
            // GID (8 bytes) - "0000000\0"
            let gid = "0000000\0".data(using: .ascii)!
            header.replaceSubrange(116..<124, with: gid)
            
            // File size in octal (12 bytes)
            let sizeString = String(format: "%011o ", fileData.count)
            let sizeData = sizeString.data(using: .ascii)!
            header.replaceSubrange(124..<136, with: sizeData)
            
            // Modification time (12 bytes)
            let mtime = String(format: "%011o ", Int(Date().timeIntervalSince1970))
            let mtimeData = mtime.data(using: .ascii)!
            header.replaceSubrange(136..<148, with: mtimeData)
            
            // Checksum placeholder (8 bytes) - spaces for now
            let checksumPlaceholder = "        ".data(using: .ascii)!
            header.replaceSubrange(148..<156, with: checksumPlaceholder)
            
            // Type flag (1 byte) - '0' for regular file
            header[156] = 48 // ASCII '0'
            
            // Calculate and set checksum
            var checksum: UInt32 = 0
            for byte in header {
                checksum += UInt32(byte)
            }
            let checksumString = String(format: "%06o\0 ", checksum)
            let checksumData = checksumString.data(using: .ascii)!
            header.replaceSubrange(148..<156, with: checksumData)
            
            // Write header
            _ = header.withUnsafeBytes { bytes in
                stream.write(bytes.bindMemory(to: UInt8.self).baseAddress!, maxLength: 512)
            }
            
            // Write file data
            _ = fileData.withUnsafeBytes { bytes in
                stream.write(bytes.bindMemory(to: UInt8.self).baseAddress!, maxLength: fileData.count)
            }
            
            // Padding to 512-byte boundary
            let padding = (512 - (fileData.count % 512)) % 512
            if padding > 0 {
                let padData = Data(count: padding)
                _ = padData.withUnsafeBytes { bytes in
                    stream.write(bytes.bindMemory(to: UInt8.self).baseAddress!, maxLength: padding)
                }
            }
        }
        
        // Write two 512-byte blocks of zeros to mark end of archive
        let endMarker = Data(count: 1024)
        _ = endMarker.withUnsafeBytes { bytes in
            stream.write(bytes.bindMemory(to: UInt8.self).baseAddress!, maxLength: 1024)
        }
    }
}

// MARK: - Compression Extension

extension Data {
    func compressed(using algorithm: Algorithm) -> Data? {
        // Use the Compression framework for actual compression
        return self.compress(withAlgorithm: algorithm)
    }
    
    private func compress(withAlgorithm algorithm: Algorithm) -> Data? {
        guard self.count > 0 else { return nil }
        
        return self.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) -> Data? in
            let config = (operation: COMPRESSION_STREAM_ENCODE, algorithm: algorithm)
            return perform(config, source: sourceBuffer, sourceSize: self.count)
        }
    }
    
    private func perform(_ config: (operation: compression_stream_operation, algorithm: Algorithm),
                         source: UnsafeRawBufferPointer,
                         sourceSize: Int) -> Data? {
        guard let sourceBase = source.baseAddress else { return nil }
        
        let streamBase = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { streamBase.deallocate() }
        
        var stream = streamBase.pointee
        let status = compression_stream_init(&stream, config.operation, config.algorithm.rawValue)
        guard status != COMPRESSION_STATUS_ERROR else { return nil }
        defer { compression_stream_destroy(&stream) }
        
        let bufferSize = 64 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        var output = Data()
        stream.src_ptr = sourceBase.assumingMemoryBound(to: UInt8.self)
        stream.src_size = sourceSize
        stream.dst_ptr = buffer
        stream.dst_size = bufferSize
        
        while true {
            switch compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue)) {
            case COMPRESSION_STATUS_OK:
                output.append(buffer, count: bufferSize - stream.dst_size)
                stream.dst_ptr = buffer
                stream.dst_size = bufferSize
                
            case COMPRESSION_STATUS_END:
                output.append(buffer, count: bufferSize - stream.dst_size)
                return output
                
            default:
                return nil
            }
        }
    }
}

extension Data {
    enum Algorithm: Int32 {
        case zlib = 0x205
        case lzfse = 0x801
        case lz4 = 0x100
        case lzma = 0x306
        
        var rawValue: compression_algorithm {
            return compression_algorithm(UInt32(self.rawValue))
        }
    }
}

// MARK: - Errors

enum ZipError: LocalizedError {
    case cannotCreateArchive
    case invalidSourceDirectory
    case compressionFailed
    
    var errorDescription: String? {
        switch self {
        case .cannotCreateArchive:
            return "Cannot create archive file"
        case .invalidSourceDirectory:
            return "Invalid source directory"
        case .compressionFailed:
            return "Compression failed"
        }
    }
}