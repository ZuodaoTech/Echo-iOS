//
//  ExportManager.swift
//  Echo
//
//  Handles export of scripts to backup files
//

import Foundation
import CoreData
import UniformTypeIdentifiers

class ExportManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var exportError: Error?
    
    // MARK: - Private Properties
    
    private let context: NSManagedObjectContext
    private let fileManager = FileManager.default
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }
    
    // MARK: - Public Methods
    
    /// Export all scripts to a backup file
    /// - Parameter includeAudio: Whether to include audio files in the backup
    /// - Returns: URL of the created backup file
    func exportAllScripts(includeAudio: Bool = true) async throws -> URL {
        await MainActor.run {
            isExporting = true
            exportProgress = 0.0
            exportError = nil
        }
        
        defer {
            Task { @MainActor in
                isExporting = false
            }
        }
        
        do {
            // Fetch all scripts
            let fetchRequest = SelftalkScript.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            let scripts = try context.fetch(fetchRequest)
            
            // Fetch all tags
            let tagRequest = Tag.fetchRequest()
            let tags = try context.fetch(tagRequest)
            
            // Create backup
            return try await createBackup(
                scripts: scripts,
                tags: tags,
                includeAudio: includeAudio
            )
        } catch {
            await MainActor.run {
                exportError = error
            }
            throw error
        }
    }
    
    /// Export selected scripts to a backup file
    func exportScripts(_ scripts: [SelftalkScript], includeAudio: Bool = true) async throws -> URL {
        await MainActor.run {
            isExporting = true
            exportProgress = 0.0
            exportError = nil
        }
        
        defer {
            Task { @MainActor in
                isExporting = false
            }
        }
        
        do {
            // Get unique tags from selected scripts
            let allTags = scripts.flatMap { $0.tagsArray }
            let uniqueTags = Array(Set(allTags))
            
            // Create backup
            return try await createBackup(
                scripts: scripts,
                tags: uniqueTags,
                includeAudio: includeAudio
            )
        } catch {
            await MainActor.run {
                exportError = error
            }
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func createBackup(scripts: [SelftalkScript], tags: [Tag], includeAudio: Bool) async throws -> URL {
        // Create temporary directory for export
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("echo-export-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // Clean up temp directory
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Update progress
        await updateProgress(0.1)
        
        // Create metadata
        var metadata = BackupMetadata()
        metadata.statistics.totalScripts = scripts.count
        metadata.exportOptions.includeAudio = includeAudio
        
        // Convert scripts to exportable format
        var exportableScripts: [ExportableScript] = []
        var totalAudioSize: Int64 = 0
        var audioFileMap: [String: URL] = [:]
        
        for (index, script) in scripts.enumerated() {
            let exportableScript = ExportableScript(from: script)
            exportableScripts.append(exportableScript)
            
            // Track audio files
            if includeAudio, let audioPath = script.audioFilePath {
                let audioURL = URL(fileURLWithPath: audioPath)
                if fileManager.fileExists(atPath: audioPath) {
                    let filename = "\(script.id.uuidString).m4a"
                    audioFileMap[filename] = audioURL
                    
                    if let attributes = try? fileManager.attributesOfItem(atPath: audioPath),
                       let fileSize = attributes[.size] as? Int64 {
                        totalAudioSize += fileSize
                    }
                    metadata.statistics.totalRecordings += 1
                }
            }
            
            metadata.statistics.totalPlayCount += Int(script.playCount)
            
            // Update progress
            let progress = 0.1 + (0.3 * Double(index + 1) / Double(scripts.count))
            await updateProgress(progress)
        }
        
        metadata.statistics.totalAudioSizeMB = Double(totalAudioSize) / 1_048_576
        
        // Convert tags to exportable format
        let exportableTags = tags.map { ExportableTag(from: $0) }
        
        // Create backup data
        let backupData = BackupData(
            metadata: metadata,
            scripts: exportableScripts,
            tags: exportableTags
        )
        
        // Write metadata.json
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let metadataJSON = try encoder.encode(metadata)
        let metadataURL = tempDir.appendingPathComponent("metadata.json")
        try metadataJSON.write(to: metadataURL)
        
        await updateProgress(0.5)
        
        // Write scripts.json
        let scriptsJSON = try encoder.encode(backupData)
        let scriptsURL = tempDir.appendingPathComponent("scripts.json")
        try scriptsJSON.write(to: scriptsURL)
        
        await updateProgress(0.6)
        
        // Copy audio files if requested
        if includeAudio && !audioFileMap.isEmpty {
            let audioDir = tempDir.appendingPathComponent("audio")
            try fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)
            
            for (index, (filename, sourceURL)) in audioFileMap.enumerated() {
                let destURL = audioDir.appendingPathComponent(filename)
                try fileManager.copyItem(at: sourceURL, to: destURL)
                
                let progress = 0.6 + (0.3 * Double(index + 1) / Double(audioFileMap.count))
                await updateProgress(progress)
            }
        }
        
        // Create manifest
        let manifest = try createManifest(for: tempDir)
        let manifestJSON = try encoder.encode(manifest)
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        try manifestJSON.write(to: manifestURL)
        
        await updateProgress(0.95)
        
        // Create ZIP file
        let zipName = "Echo-Backup-\(dateFormatter.string(from: Date())).zip"
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let zipURL = documentsDir.appendingPathComponent(zipName)
        
        try await createZipArchive(from: tempDir, to: zipURL)
        
        await updateProgress(1.0)
        
        return zipURL
    }
    
    private struct Manifest: Codable {
        let fileCount: Int
        let totalSizeBytes: Int64
        let checksums: [String: String]
        
        enum CodingKeys: String, CodingKey {
            case fileCount = "file_count"
            case totalSizeBytes = "total_size_bytes"
            case checksums
        }
    }
    
    private func createManifest(for directory: URL) throws -> Manifest {
        var checksums: [String: String] = [:]
        var totalSize: Int64 = 0
        var fileCount = 0
        
        // Enumerate all files
        if let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) {
            for case let fileURL as URL in enumerator {
                let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                
                if attributes.isRegularFile == true {
                    fileCount += 1
                    
                    if let fileSize = attributes.fileSize {
                        totalSize += Int64(fileSize)
                    }
                    
                    // Calculate relative path
                    let relativePath = fileURL.path.replacingOccurrences(
                        of: directory.path + "/",
                        with: ""
                    )
                    
                    // Simple checksum (for now, just file size)
                    checksums[relativePath] = String(attributes.fileSize ?? 0)
                }
            }
        }
        
        return Manifest(
            fileCount: fileCount,
            totalSizeBytes: totalSize,
            checksums: checksums
        )
    }
    
    private func createZipArchive(from sourceDir: URL, to destinationURL: URL) async throws {
        // For iOS, we need to use a different approach since Process is not available
        // We'll use FileManager's built-in compression or implement a simple archive
        
        // First, ensure destination doesn't exist
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // Get all files to archive
        var filesToArchive: [(URL, String)] = []
        
        if let enumerator = fileManager.enumerator(
            at: sourceDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let attributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if attributes.isRegularFile == true {
                    let relativePath = fileURL.path.replacingOccurrences(
                        of: sourceDir.path + "/",
                        with: ""
                    )
                    filesToArchive.append((fileURL, relativePath))
                }
            }
        }
        
        // Create a simple tar-like archive (for now, we'll just copy to a temp location)
        // In production, you'd want to use a proper ZIP library
        
        // For MVP, we'll create a directory with .zip extension
        // iOS will treat it as a single file for sharing
        let tempArchive = fileManager.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).archive")
        
        try fileManager.createDirectory(at: tempArchive, withIntermediateDirectories: true)
        
        // Copy all files maintaining structure
        for (sourceFile, relativePath) in filesToArchive {
            let destFile = tempArchive.appendingPathComponent(relativePath)
            let destDir = destFile.deletingLastPathComponent()
            
            if !fileManager.fileExists(atPath: destDir.path) {
                try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
            }
            
            try fileManager.copyItem(at: sourceFile, to: destFile)
        }
        
        // Compress using Data compression
        try compressDirectory(tempArchive, to: destinationURL)
        
        // Clean up
        try? fileManager.removeItem(at: tempArchive)
    }
    
    private func compressDirectory(_ sourceDir: URL, to destinationURL: URL) throws {
        // Create a simple archive format
        var archiveData = Data()
        
        // Add a simple header
        let header = "ECHO_BACKUP_V1\n"
        archiveData.append(header.data(using: .utf8)!)
        
        // Get all files
        if let enumerator = fileManager.enumerator(
            at: sourceDir,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]
        ) {
            for case let fileURL as URL in enumerator {
                let attributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                
                if attributes.isRegularFile == true {
                    let relativePath = fileURL.path.replacingOccurrences(
                        of: sourceDir.path + "/",
                        with: ""
                    )
                    
                    // Write file entry
                    let fileData = try Data(contentsOf: fileURL)
                    let entry = "\(relativePath)|\(fileData.count)\n"
                    archiveData.append(entry.data(using: .utf8)!)
                    archiveData.append(fileData)
                    archiveData.append("\n".data(using: .utf8)!)
                }
            }
        }
        
        // Save the archive data
        // Note: In production, you'd want to use actual ZIP compression
        // For now, we'll save as a simple archive format
        try archiveData.write(to: destinationURL)
    }
    
    private func updateProgress(_ value: Double) async {
        await MainActor.run {
            exportProgress = value
        }
    }
}

// MARK: - Export Errors

enum ExportError: LocalizedError {
    case noScriptsToExport
    case insufficientSpace(required: Int64, available: Int64)
    case zipCreationFailed(String)
    case fileOperationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noScriptsToExport:
            return NSLocalizedString("No scripts to export", comment: "")
        case .insufficientSpace(let required, let available):
            let requiredMB = Double(required) / 1_048_576
            let availableMB = Double(available) / 1_048_576
            return String(format: NSLocalizedString("Insufficient space. Need %.1fMB, available %.1fMB", comment: ""), requiredMB, availableMB)
        case .zipCreationFailed(let error):
            return String(format: NSLocalizedString("Failed to create backup file: %@", comment: ""), error)
        case .fileOperationFailed(let error):
            return String(format: NSLocalizedString("File operation failed: %@", comment: ""), error)
        }
    }
}