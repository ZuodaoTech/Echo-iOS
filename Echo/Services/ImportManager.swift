//
//  ImportManager.swift
//  Echo
//
//  Handles import of backup files with conflict resolution
//

import Foundation
import CoreData
import UniformTypeIdentifiers

class ImportManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isImporting = false
    @Published var importProgress: Double = 0.0
    @Published var importError: Error?
    @Published var currentImportPreview: ImportPreview?
    
    // MARK: - Private Properties
    
    private var context: NSManagedObjectContext!
    private let fileManager = FileManager.default
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext? = nil) {
        self.context = context
    }
    
    func setContext(_ context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Public Methods
    
    /// Validate a backup file
    func validateBackup(at url: URL) async -> ImportValidation {
        do {
            // Check if file exists
            guard fileManager.fileExists(atPath: url.path) else {
                return ImportValidation(
                    isValid: false,
                    errors: [.missingRequiredFile(url.lastPathComponent)],
                    warnings: [],
                    backupInfo: nil
                )
            }
            
            // Extract backup to temp directory
            let tempDir = try await extractBackup(from: url)
            defer { try? fileManager.removeItem(at: tempDir) }
            
            // Validate structure
            let validation = try await validateBackupStructure(at: tempDir)
            
            return validation
            
        } catch {
            return ImportValidation(
                isValid: false,
                errors: [.invalidFormat(error.localizedDescription)],
                warnings: [],
                backupInfo: nil
            )
        }
    }
    
    /// Preview what will be imported
    func previewImport(from url: URL) async throws -> ImportPreview {
        // Extract backup
        let tempDir = try await extractBackup(from: url)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        // Load backup data
        let backupData = try await loadBackupData(from: tempDir)
        
        // Analyze conflicts
        let conflicts = await analyzeConflicts(for: backupData.scripts)
        
        // Calculate statistics
        let scriptsToImport = backupData.scripts.filter { script in
            !conflicts.contains { $0.imported.id == script.id && $0.reason == .sameID }
        }.count
        
        let scriptsToUpdate = conflicts.filter { $0.reason == .sameID }.count
        let scriptsToSkip = 0 // Will be determined by user's conflict resolution choice
        
        // Count new tags
        let existingTagNames = try context.fetch(Tag.fetchRequest()).map { $0.name }
        let newTags = backupData.tags.filter { !existingTagNames.contains($0.name) }.count
        
        // Estimate size
        let estimatedSize = try await calculateImportSize(at: tempDir)
        
        let preview = ImportPreview(
            backupMetadata: backupData.metadata,
            scriptsToImport: scriptsToImport,
            scriptsToUpdate: scriptsToUpdate,
            scriptsToSkip: scriptsToSkip,
            newTags: newTags,
            conflicts: conflicts,
            estimatedSize: estimatedSize
        )
        
        await MainActor.run {
            self.currentImportPreview = preview
        }
        
        return preview
    }
    
    /// Perform the actual import
    func performImport(
        from url: URL,
        resolution: ImportConflictResolution = .smartMerge
    ) async throws -> ImportResult {
        await MainActor.run {
            isImporting = true
            importProgress = 0.0
            importError = nil
        }
        
        defer {
            Task { @MainActor in
                isImporting = false
            }
        }
        
        do {
            // Extract backup
            let tempDir = try await extractBackup(from: url)
            defer { try? fileManager.removeItem(at: tempDir) }
            
            await updateProgress(0.1)
            
            // Load backup data
            let backupData = try await loadBackupData(from: tempDir)
            
            await updateProgress(0.2)
            
            // Import tags first
            try await importTags(backupData.tags)
            
            await updateProgress(0.3)
            
            // Import scripts with conflict resolution
            let result = try await importScripts(
                backupData.scripts,
                from: tempDir,
                resolution: resolution
            )
            
            await updateProgress(1.0)
            
            // Save context
            try context.save()
            
            return result
            
        } catch {
            await MainActor.run {
                importError = error
            }
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func extractBackup(from url: URL) async throws -> URL {
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("echo-import-\(UUID().uuidString)")
        
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Read archive data
        let archiveData = try Data(contentsOf: url)
        
        // Check if it's our custom format or try to extract as standard archive
        if let header = String(data: archiveData.prefix(15), encoding: .utf8),
           header == "ECHO_BACKUP_V1\n" {
            // Extract our custom format
            try extractCustomArchive(archiveData, to: tempDir)
        } else {
            // Assume it's a standard format (for future ZIP support)
            throw ImportError.invalidFormat("Unsupported backup format")
        }
        
        return tempDir
    }
    
    private func extractCustomArchive(_ data: Data, to directory: URL) throws {
        // Parse our simple archive format
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidFormat("Cannot read archive content")
        }
        
        let lines = content.components(separatedBy: "\n")
        guard lines.first == "ECHO_BACKUP_V1" else {
            throw ImportError.invalidFormat("Invalid archive header")
        }
        
        var currentIndex = 1
        while currentIndex < lines.count {
            let line = lines[currentIndex]
            if line.isEmpty {
                currentIndex += 1
                continue
            }
            
            // Parse file entry: path|size
            let parts = line.components(separatedBy: "|")
            guard parts.count == 2,
                  let size = Int(parts[1]) else {
                currentIndex += 1
                continue
            }
            
            let relativePath = parts[0]
            currentIndex += 1
            
            // Read file data
            var fileContent = ""
            var bytesRead = 0
            while currentIndex < lines.count && bytesRead < size {
                let dataLine = lines[currentIndex]
                fileContent += dataLine
                if currentIndex < lines.count - 1 {
                    fileContent += "\n"
                }
                bytesRead = fileContent.utf8.count
                currentIndex += 1
                
                if bytesRead >= size {
                    // Trim to exact size
                    let data = fileContent.data(using: .utf8)!
                    let trimmedData = data.prefix(size)
                    
                    // Write to file
                    let fileURL = directory.appendingPathComponent(relativePath)
                    let fileDir = fileURL.deletingLastPathComponent()
                    
                    if !fileManager.fileExists(atPath: fileDir.path) {
                        try fileManager.createDirectory(at: fileDir, withIntermediateDirectories: true)
                    }
                    
                    try trimmedData.write(to: fileURL)
                    break
                }
            }
        }
    }
    
    private func validateBackupStructure(at directory: URL) async throws -> ImportValidation {
        var errors: [ImportError] = []
        var warnings: [ImportWarning] = []
        
        // Check for required files
        let metadataURL = directory.appendingPathComponent("metadata.json")
        let scriptsURL = directory.appendingPathComponent("scripts.json")
        
        if !fileManager.fileExists(atPath: metadataURL.path) {
            errors.append(.missingRequiredFile("metadata.json"))
        }
        
        if !fileManager.fileExists(atPath: scriptsURL.path) {
            errors.append(.missingRequiredFile("scripts.json"))
        }
        
        // If we have errors, return invalid
        if !errors.isEmpty {
            return ImportValidation(
                isValid: false,
                errors: errors,
                warnings: warnings,
                backupInfo: nil
            )
        }
        
        // Try to load metadata
        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try decoder.decode(BackupMetadata.self, from: metadataData)
        
        // Check version compatibility
        if metadata.version > "1.0" {
            warnings.append(.futureVersion(version: metadata.version))
        }
        
        return ImportValidation(
            isValid: true,
            errors: errors,
            warnings: warnings,
            backupInfo: metadata
        )
    }
    
    private func loadBackupData(from directory: URL) async throws -> BackupData {
        let scriptsURL = directory.appendingPathComponent("scripts.json")
        let scriptsData = try Data(contentsOf: scriptsURL)
        let backupData = try decoder.decode(BackupData.self, from: scriptsData)
        return backupData
    }
    
    private func analyzeConflicts(for scripts: [ExportableScript]) async -> [ImportConflict] {
        var conflicts: [ImportConflict] = []
        
        for importedScript in scripts {
            // Check by ID
            let fetchRequest = SelftalkScript.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", importedScript.id as CVarArg)
            fetchRequest.fetchLimit = 1
            
            if let existingScript = try? context.fetch(fetchRequest).first {
                conflicts.append(ImportConflict(
                    imported: importedScript,
                    existing: existingScript,
                    reason: .sameID
                ))
            } else {
                // Check for similar content
                let normalizedText = importedScript.scriptText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                
                let similarRequest = SelftalkScript.fetchRequest()
                similarRequest.predicate = NSPredicate(
                    format: "scriptText CONTAINS[c] %@",
                    String(normalizedText.prefix(50))
                )
                
                if let similarScript = try? context.fetch(similarRequest).first {
                    let similarity = calculateSimilarity(
                        importedScript.scriptText,
                        similarScript.scriptText
                    )
                    
                    if similarity > 0.8 {
                        conflicts.append(ImportConflict(
                            imported: importedScript,
                            existing: similarScript,
                            reason: .similarContent(similarity: similarity)
                        ))
                    }
                }
            }
        }
        
        return conflicts
    }
    
    private func calculateSimilarity(_ text1: String, _ text2: String) -> Double {
        let normalized1 = text1.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalized2 = text2.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if normalized1 == normalized2 {
            return 1.0
        }
        
        // Simple similarity based on common prefix
        let commonPrefix = normalized1.commonPrefix(with: normalized2)
        let maxLength = max(normalized1.count, normalized2.count)
        
        return Double(commonPrefix.count) / Double(maxLength)
    }
    
    private func importTags(_ tags: [ExportableTag]) async throws {
        for tag in tags {
            // Check if tag exists
            let fetchRequest = Tag.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", tag.name)
            fetchRequest.fetchLimit = 1
            
            if (try? context.fetch(fetchRequest).first) == nil {
                // Create new tag
                let newTag = Tag(context: context)
                newTag.id = tag.id
                newTag.name = tag.name
                newTag.createdAt = tag.createdAt
            }
        }
    }
    
    private func importScripts(
        _ scripts: [ExportableScript],
        from directory: URL,
        resolution: ImportConflictResolution
    ) async throws -> ImportResult {
        var imported = 0
        var updated = 0
        var skipped = 0
        var failed: [(script: ExportableScript, error: Error)] = []
        
        let totalScripts = scripts.count
        
        for (index, exportableScript) in scripts.enumerated() {
            // Update progress
            let progress = 0.3 + (0.6 * Double(index) / Double(totalScripts))
            await updateProgress(progress)
            
            do {
                // Check for existing script
                let fetchRequest = SelftalkScript.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", exportableScript.id as CVarArg)
                fetchRequest.fetchLimit = 1
                
                if let existingScript = try context.fetch(fetchRequest).first {
                    // Handle conflict
                    switch resolution {
                    case .keepExisting:
                        skipped += 1
                        continue
                        
                    case .replaceExisting:
                        updateScript(existingScript, from: exportableScript, directory: directory)
                        updated += 1
                        
                    case .mergeDuplicate:
                        createNewScript(from: exportableScript, directory: directory, withSuffix: true)
                        imported += 1
                        
                    case .smartMerge:
                        if exportableScript.updatedAt > existingScript.updatedAt {
                            updateScript(existingScript, from: exportableScript, directory: directory)
                            // Merge play counts
                            existingScript.playCount += exportableScript.playCount
                        } else {
                            // Keep existing but update play count
                            existingScript.playCount += exportableScript.playCount
                        }
                        updated += 1
                    }
                } else {
                    // No conflict, create new script
                    createNewScript(from: exportableScript, directory: directory, withSuffix: false)
                    imported += 1
                }
                
            } catch {
                failed.append((exportableScript, error))
            }
        }
        
        return ImportResult(
            imported: imported,
            updated: updated,
            skipped: skipped,
            failed: failed
        )
    }
    
    private func updateScript(
        _ script: SelftalkScript,
        from exportable: ExportableScript,
        directory: URL
    ) {
        script.scriptText = exportable.scriptText
        script.repetitions = exportable.repetitions
        script.intervalSeconds = exportable.intervalSeconds
        script.privateModeEnabled = exportable.privacyMode
        script.updatedAt = exportable.updatedAt
        
        // Update audio if present
        if let audioInfo = exportable.audio {
            let audioURL = directory.appendingPathComponent("audio").appendingPathComponent(audioInfo.filename)
            if fileManager.fileExists(atPath: audioURL.path) {
                // Copy audio file to app's audio directory
                if let newAudioPath = copyAudioFile(from: audioURL, scriptId: script.id) {
                    script.audioFilePath = newAudioPath
                    script.audioDuration = audioInfo.duration
                }
            }
        }
        
        // Update transcription
        if let transcription = exportable.transcription {
            script.transcribedText = transcription.text
            script.transcriptionLanguage = transcription.language
        }
    }
    
    private func createNewScript(
        from exportable: ExportableScript,
        directory: URL,
        withSuffix: Bool
    ) {
        let script = SelftalkScript(context: context)
        script.id = withSuffix ? UUID() : exportable.id
        script.scriptText = exportable.scriptText + (withSuffix ? " (Imported)" : "")
        script.repetitions = exportable.repetitions
        script.intervalSeconds = exportable.intervalSeconds
        script.privateModeEnabled = exportable.privacyMode
        script.createdAt = exportable.createdAt
        script.updatedAt = exportable.updatedAt
        script.playCount = exportable.playCount
        script.lastPlayedAt = exportable.lastPlayedAt
        
        // Import audio if present
        if let audioInfo = exportable.audio {
            let audioURL = directory.appendingPathComponent("audio").appendingPathComponent(audioInfo.filename)
            if fileManager.fileExists(atPath: audioURL.path) {
                if let newAudioPath = copyAudioFile(from: audioURL, scriptId: script.id) {
                    script.audioFilePath = newAudioPath
                    script.audioDuration = audioInfo.duration
                }
            }
        }
        
        // Import transcription
        if let transcription = exportable.transcription {
            script.transcribedText = transcription.text
            script.transcriptionLanguage = transcription.language
        }
        
        // Add tags
        for tagName in exportable.tagNames {
            let fetchRequest = Tag.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", tagName)
            fetchRequest.fetchLimit = 1
            
            if let tag = try? context.fetch(fetchRequest).first {
                script.addToTags(tag)
            }
        }
    }
    
    private func copyAudioFile(from sourceURL: URL, scriptId: UUID) -> String? {
        // Get app's audio directory
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let recordingsDir = "\(documentsPath)/Recordings"
        
        // Ensure directory exists
        if !fileManager.fileExists(atPath: recordingsDir) {
            try? fileManager.createDirectory(atPath: recordingsDir, withIntermediateDirectories: true)
        }
        
        let destinationPath = "\(recordingsDir)/\(scriptId).m4a"
        
        do {
            // Remove existing file if it exists
            if fileManager.fileExists(atPath: destinationPath) {
                try fileManager.removeItem(atPath: destinationPath)
            }
            
            // Copy new file
            try fileManager.copyItem(at: sourceURL, to: URL(fileURLWithPath: destinationPath))
            return destinationPath
        } catch {
            print("Failed to copy audio file: \(error)")
            return nil
        }
    }
    
    private func calculateImportSize(at directory: URL) async throws -> Int64 {
        var totalSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) {
            for case let fileURL as URL in enumerator {
                let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = attributes.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return totalSize
    }
    
    private func updateProgress(_ value: Double) async {
        await MainActor.run {
            importProgress = value
        }
    }
}