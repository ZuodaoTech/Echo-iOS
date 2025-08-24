import Foundation
import CoreData
import UniformTypeIdentifiers

/// Handles importing scripts from .echo bundle format
class ImportService {
    
    enum ImportConflictResolution {
        case skip           // Skip duplicates
        case replace        // Replace existing
        case keepBoth       // Rename imported (add suffix)
        case merge          // Combine, newest audio wins
    }
    
    enum ImportError: LocalizedError {
        case invalidBundle
        case unsupportedVersion
        case manifestMissing
        case importFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidBundle:
                return "Invalid or corrupted bundle file"
            case .unsupportedVersion:
                return "This bundle was created with an incompatible version"
            case .manifestMissing:
                return "Bundle manifest is missing or corrupted"
            case .importFailed(let reason):
                return "Import failed: \(reason)"
            }
        }
    }
    
    struct ImportResult {
        let scriptsImported: Int
        let scriptsSkipped: Int
        let categoriesImported: Int
        let errors: [String]
        
        var summary: String {
            var parts: [String] = []
            if scriptsImported > 0 {
                parts.append("\(scriptsImported) script\(scriptsImported == 1 ? "" : "s") imported")
            }
            if scriptsSkipped > 0 {
                parts.append("\(scriptsSkipped) skipped")
            }
            if categoriesImported > 0 {
                parts.append("\(categoriesImported) categor\(categoriesImported == 1 ? "y" : "ies")")
            }
            return parts.joined(separator: ", ")
        }
    }
    
    private let fileManager = FileManager.default
    private let audioFileManager = AudioFileManager()
    
    /// Import scripts from a bundle URL
    func importBundle(from url: URL,
                     conflictResolution: ImportConflictResolution = .skip,
                     context: NSManagedObjectContext) async -> ImportResult {
        
        do {
            // Start accessing security-scoped resource if needed
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Check if it's a bundle or single file
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
            
            guard exists else {
                throw ImportError.invalidBundle
            }
            
            if isDirectory.boolValue {
                // Import .echo bundle directory
                let result = try await importBundleDirectory(
                    url,
                    conflictResolution: conflictResolution,
                    context: context
                )
                return result
            } else {
                // Check file extension
                switch url.pathExtension.lowercased() {
                case "echo":
                    // Unzip if needed and import
                    let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
                    defer {
                        try? fileManager.removeItem(at: tempDir)
                    }
                    
                    // For now, assume it's already a directory (not zipped)
                    return try await importBundleDirectory(url, conflictResolution: conflictResolution, context: context)
                    
                case "json":
                    // Import JSON format
                    return try await importJSON(from: url, conflictResolution: conflictResolution, context: context)
                    
                case "txt":
                    // Import text format (limited - no audio)
                    return try await importText(from: url, context: context)
                    
                default:
                    throw ImportError.invalidBundle
                }
            }
        } catch {
            return ImportResult(
                scriptsImported: 0,
                scriptsSkipped: 0,
                categoriesImported: 0,
                errors: [error.localizedDescription]
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func importBundleDirectory(_ bundleURL: URL,
                                      conflictResolution: ImportConflictResolution,
                                      context: NSManagedObjectContext) async throws -> ImportResult {
        
        var scriptsImported = 0
        var scriptsSkipped = 0
        var categoriesImported = 0
        var errors: [String] = []
        
        // Read manifest
        let manifestURL = bundleURL.appendingPathComponent("manifest.json")
        guard let manifestData = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(ExportManifest.self, from: manifestData) else {
            throw ImportError.manifestMissing
        }
        
        // Check version compatibility
        guard manifest.version == "1.0" else {
            throw ImportError.unsupportedVersion
        }
        
        // Import categories first
        let categoriesURL = bundleURL.appendingPathComponent("categories.json")
        if let categoriesData = try? Data(contentsOf: categoriesURL),
           let categoryExports = try? JSONDecoder().decode([CategoryExport].self, from: categoriesData) {
            
            for categoryExport in categoryExports {
                // Check if category exists
                let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", categoryExport.name)
                
                if (try? context.fetch(fetchRequest).first) != nil {
                    // Category exists, use it
                    continue
                } else {
                    // Create new category
                    let category = Category(context: context)
                    category.id = categoryExport.id
                    category.name = categoryExport.name
                    category.sortOrder = Int32(categoryExport.sortOrder)
                    categoriesImported += 1
                }
            }
        }
        
        // Import scripts
        let scriptsDir = bundleURL.appendingPathComponent("scripts")
        let scriptFiles = try fileManager.contentsOfDirectory(at: scriptsDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        for (index, scriptFile) in scriptFiles.enumerated() {
            do {
                let scriptData = try Data(contentsOf: scriptFile)
                let scriptExport = try JSONDecoder().decode(ScriptExport.self, from: scriptData)
                
                // Check for conflicts
                let existingScript = try await checkForExistingScript(
                    id: scriptExport.id,
                    text: scriptExport.scriptText,
                    context: context
                )
                
                if let existing = existingScript {
                    switch conflictResolution {
                    case .skip:
                        scriptsSkipped += 1
                        continue
                        
                    case .replace:
                        // Update existing script
                        updateScript(existing, from: scriptExport, context: context)
                        
                    case .keepBoth:
                        // Create new script with modified text
                        let modifiedScript = createScript(from: scriptExport, context: context)
                        modifiedScript.scriptText += " (Imported)"
                        scriptsImported += 1
                        
                    case .merge:
                        // Merge: keep newer audio, combine metadata
                        mergeScript(existing, with: scriptExport, context: context)
                    }
                } else {
                    // No conflict, create new script
                    let newScript = createScript(from: scriptExport, context: context)
                    
                    // Copy audio file if it exists
                    if manifest.includesAudio {
                        let audioFileName = "script_\(index).m4a"
                        let sourceAudioURL = scriptsDir.appendingPathComponent(audioFileName)
                        
                        if fileManager.fileExists(atPath: sourceAudioURL.path) {
                            let destAudioURL = audioFileManager.audioURL(for: newScript.id)
                            try fileManager.copyItem(at: sourceAudioURL, to: destAudioURL)
                            newScript.audioFilePath = destAudioURL.path
                        }
                    }
                    
                    scriptsImported += 1
                }
            } catch {
                errors.append("Failed to import script \(scriptFile.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        // Import settings (optional - only if user wants)
        // For now, we'll skip settings import to avoid overwriting user preferences
        
        // Save context
        do {
            try context.save()
        } catch {
            errors.append("Failed to save imported data: \(error.localizedDescription)")
        }
        
        return ImportResult(
            scriptsImported: scriptsImported,
            scriptsSkipped: scriptsSkipped,
            categoriesImported: categoriesImported,
            errors: errors
        )
    }
    
    private func importJSON(from url: URL,
                           conflictResolution: ImportConflictResolution,
                           context: NSManagedObjectContext) async throws -> ImportResult {
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let completeExport = try decoder.decode(CompleteExport.self, from: data)
        
        // Create a temporary bundle structure and use existing import logic
        let tempBundleURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempBundleURL, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempBundleURL)
        }
        
        // Write manifest
        let manifestData = try JSONEncoder().encode(completeExport.manifest)
        try manifestData.write(to: tempBundleURL.appendingPathComponent("manifest.json"))
        
        // Write categories
        let categoriesData = try JSONEncoder().encode(completeExport.categories)
        try categoriesData.write(to: tempBundleURL.appendingPathComponent("categories.json"))
        
        // Write scripts
        let scriptsDir = tempBundleURL.appendingPathComponent("scripts")
        try fileManager.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        
        for (index, script) in completeExport.scripts.enumerated() {
            let scriptData = try JSONEncoder().encode(script)
            try scriptData.write(to: scriptsDir.appendingPathComponent("script_\(index).json"))
        }
        
        return try await importBundleDirectory(tempBundleURL, conflictResolution: conflictResolution, context: context)
    }
    
    private func importText(from url: URL, context: NSManagedObjectContext) async throws -> ImportResult {
        // Very basic text import - just creates scripts from text content
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        var scriptsImported = 0
        var currentScript: String?
        
        for line in lines {
            if line.hasPrefix("Script: ") {
                if let scriptText = currentScript {
                    // Create script from previous text
                    let script = SelftalkScript(context: context)
                    script.id = UUID()
                    script.scriptText = scriptText
                    script.repetitions = 3
                    script.intervalSeconds = 2.0
                    script.privacyModeEnabled = true
                    script.createdAt = Date()
                    script.updatedAt = Date()
                    scriptsImported += 1
                }
                currentScript = String(line.dropFirst(8))
            }
        }
        
        // Don't forget the last script
        if let scriptText = currentScript {
            let script = SelftalkScript(context: context)
            script.id = UUID()
            script.scriptText = scriptText
            script.repetitions = 3
            script.intervalSeconds = 2.0
            script.privacyModeEnabled = true
            script.createdAt = Date()
            script.updatedAt = Date()
            scriptsImported += 1
        }
        
        try context.save()
        
        return ImportResult(
            scriptsImported: scriptsImported,
            scriptsSkipped: 0,
            categoriesImported: 0,
            errors: []
        )
    }
    
    private func checkForExistingScript(id: UUID,
                                       text: String,
                                       context: NSManagedObjectContext) async throws -> SelftalkScript? {
        
        let fetchRequest: NSFetchRequest<SelftalkScript> = SelftalkScript.fetchRequest()
        
        // First check by ID
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let existing = try context.fetch(fetchRequest).first {
            return existing
        }
        
        // Then check by text similarity (exact match for now)
        fetchRequest.predicate = NSPredicate(format: "scriptText == %@", text)
        return try context.fetch(fetchRequest).first
    }
    
    private func createScript(from export: ScriptExport, context: NSManagedObjectContext) -> SelftalkScript {
        let script = SelftalkScript(context: context)
        script.id = UUID() // Generate new ID to avoid conflicts
        script.scriptText = export.scriptText
        script.repetitions = export.repetitions
        script.intervalSeconds = export.intervalSeconds
        script.audioDuration = export.audioDuration
        script.privacyModeEnabled = export.privacyModeEnabled
        script.createdAt = export.createdAt
        script.updatedAt = Date() // Update to current date
        script.lastPlayedAt = export.lastPlayedAt
        script.playCount = export.playCount
        script.transcribedText = export.transcribedText
        script.transcriptionLanguage = export.transcriptionLanguage
        
        // Link to category if exists
        if let categoryId = export.categoryId {
            let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", categoryId as CVarArg)
            script.category = try? context.fetch(fetchRequest).first
        }
        
        return script
    }
    
    private func updateScript(_ script: SelftalkScript, from export: ScriptExport, context: NSManagedObjectContext) {
        script.scriptText = export.scriptText
        script.repetitions = export.repetitions
        script.intervalSeconds = export.intervalSeconds
        script.privacyModeEnabled = export.privacyModeEnabled
        script.updatedAt = Date()
        script.transcribedText = export.transcribedText
        script.transcriptionLanguage = export.transcriptionLanguage
    }
    
    private func mergeScript(_ existing: SelftalkScript, with export: ScriptExport, context: NSManagedObjectContext) {
        // Keep the newer audio (check by updated date)
        if export.updatedAt > existing.updatedAt {
            existing.audioDuration = export.audioDuration
        }
        
        // Merge play counts
        existing.playCount += export.playCount
        
        // Update text if newer
        if export.updatedAt > existing.updatedAt {
            existing.scriptText = export.scriptText
            existing.transcribedText = export.transcribedText
        }
        
        existing.updatedAt = Date()
    }
}