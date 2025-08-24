import Foundation
import CoreData
import UniformTypeIdentifiers

/// Handles exporting scripts to .echo bundle format
class ExportService {
    
    enum ExportFormat {
        case bundle     // Full .echo bundle with optional audio
        case textOnly   // Plain text file
        case json       // JSON format for developers
    }
    
    enum ExportError: LocalizedError {
        case noScriptsToExport
        case bundleCreationFailed
        case fileWriteFailed
        
        var errorDescription: String? {
            switch self {
            case .noScriptsToExport:
                return "No scripts to export"
            case .bundleCreationFailed:
                return "Failed to create export bundle"
            case .fileWriteFailed:
                return "Failed to write export file"
            }
        }
    }
    
    private let fileManager = FileManager.default
    private let audioFileManager = AudioFileManager()
    
    /// Export scripts to a bundle format
    func exportScripts(_ scripts: [SelftalkScript],
                      includeAudio: Bool = true,
                      format: ExportFormat = .bundle) throws -> URL {
        
        guard !scripts.isEmpty else {
            throw ExportError.noScriptsToExport
        }
        
        switch format {
        case .bundle:
            return try createBundle(scripts: scripts, includeAudio: includeAudio)
        case .textOnly:
            return try createTextExport(scripts: scripts)
        case .json:
            return try createJSONExport(scripts: scripts, includeAudio: includeAudio)
        }
    }
    
    /// Export a single script
    func exportScript(_ script: SelftalkScript, includeAudio: Bool = true) throws -> URL {
        return try exportScripts([script], includeAudio: includeAudio)
    }
    
    // MARK: - Private Methods
    
    private func createBundle(scripts: [SelftalkScript], includeAudio: Bool) throws -> URL {
        // Create temporary directory for bundle
        let bundleName = "Echo_Export_\(DateFormatter.exportDateFormatter.string(from: Date()))"
        let bundleURL = fileManager.temporaryDirectory
            .appendingPathComponent(bundleName)
            .appendingPathExtension("echo")
        
        // Create bundle directory structure
        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        
        let scriptsDir = bundleURL.appendingPathComponent("scripts")
        try fileManager.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        
        // Create manifest
        let manifest = ExportManifest(
            version: "1.0",
            exportDate: Date(),
            scriptCount: scripts.count,
            includesAudio: includeAudio,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0"
        )
        
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: bundleURL.appendingPathComponent("manifest.json"))
        
        // Export categories
        let categories = Set(scripts.compactMap { $0.category })
        let categoryExports = categories.map { CategoryExport(from: $0) }
        let categoriesData = try JSONEncoder().encode(categoryExports)
        try categoriesData.write(to: bundleURL.appendingPathComponent("categories.json"))
        
        // Export each script
        for (index, script) in scripts.enumerated() {
            let scriptExport = ScriptExport(from: script)
            let scriptData = try JSONEncoder().encode(scriptExport)
            let scriptFileName = "script_\(index).json"
            try scriptData.write(to: scriptsDir.appendingPathComponent(scriptFileName))
            
            // Copy audio file if requested and exists
            if includeAudio && audioFileManager.audioFileExists(for: script.id) {
                let audioURL = audioFileManager.audioURL(for: script.id)
                let audioFileName = "script_\(index).m4a"
                let destURL = scriptsDir.appendingPathComponent(audioFileName)
                try fileManager.copyItem(at: audioURL, to: destURL)
            }
        }
        
        // Create settings export
        let settings = ExportSettings(
            privacyModeDefault: UserDefaults.standard.bool(forKey: "privacyModeDefault"),
            defaultRepetitions: UserDefaults.standard.integer(forKey: "defaultRepetitions"),
            defaultInterval: UserDefaults.standard.double(forKey: "defaultInterval"),
            defaultTranscriptionLanguage: UserDefaults.standard.string(forKey: "defaultTranscriptionLanguage") ?? "en-US",
            voiceEnhancementEnabled: UserDefaults.standard.bool(forKey: "voiceEnhancementEnabled"),
            autoTrimSilence: UserDefaults.standard.object(forKey: "autoTrimSilence") as? Bool ?? true,
            silenceTrimSensitivity: UserDefaults.standard.string(forKey: "silenceTrimSensitivity") ?? "medium"
        )
        
        let settingsData = try JSONEncoder().encode(settings)
        try settingsData.write(to: bundleURL.appendingPathComponent("settings.json"))
        
        return bundleURL
    }
    
    private func createTextExport(scripts: [SelftalkScript]) throws -> URL {
        var textContent = "Echo Scripts Export\n"
        textContent += "Date: \(DateFormatter.exportDateFormatter.string(from: Date()))\n"
        textContent += "Total Scripts: \(scripts.count)\n"
        textContent += String(repeating: "=", count: 50) + "\n\n"
        
        for script in scripts {
            textContent += "Script: \(script.scriptText)\n"
            textContent += "Category: \(script.category?.name ?? "Uncategorized")\n"
            textContent += "Repetitions: \(script.repetitions)\n"
            textContent += "Interval: \(script.intervalSeconds)s\n"
            textContent += "Privacy Mode: \(script.privacyModeEnabled ? "Yes" : "No")\n"
            if let transcript = script.transcribedText {
                textContent += "Transcript: \(transcript)\n"
            }
            textContent += String(repeating: "-", count: 30) + "\n\n"
        }
        
        let fileName = "Echo_Scripts_\(DateFormatter.exportDateFormatter.string(from: Date())).txt"
        let fileURL = fileManager.temporaryDirectory.appendingPathComponent(fileName)
        
        try textContent.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private func createJSONExport(scripts: [SelftalkScript], includeAudio: Bool) throws -> URL {
        let export = CompleteExport(
            manifest: ExportManifest(
                version: "1.0",
                exportDate: Date(),
                scriptCount: scripts.count,
                includesAudio: false, // JSON doesn't include audio files
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0"
            ),
            scripts: scripts.map { ScriptExport(from: $0) },
            categories: Set(scripts.compactMap { $0.category }).map { CategoryExport(from: $0) }
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(export)
        
        let fileName = "Echo_Export_\(DateFormatter.exportDateFormatter.string(from: Date())).json"
        let fileURL = fileManager.temporaryDirectory.appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        return fileURL
    }
}

// MARK: - Export Models

struct ExportManifest: Codable {
    let version: String
    let exportDate: Date
    let scriptCount: Int
    let includesAudio: Bool
    let appVersion: String
}

struct ScriptExport: Codable {
    let id: UUID
    let scriptText: String
    let repetitions: Int16
    let intervalSeconds: Double
    let audioDuration: Double
    let privacyModeEnabled: Bool
    let createdAt: Date
    let updatedAt: Date
    let lastPlayedAt: Date?
    let playCount: Int32
    let categoryId: UUID?
    let transcribedText: String?
    let transcriptionLanguage: String?
    
    init(from script: SelftalkScript) {
        self.id = script.id
        self.scriptText = script.scriptText
        self.repetitions = script.repetitions
        self.intervalSeconds = script.intervalSeconds
        self.audioDuration = script.audioDuration
        self.privacyModeEnabled = script.privacyModeEnabled
        self.createdAt = script.createdAt
        self.updatedAt = script.updatedAt
        self.lastPlayedAt = script.lastPlayedAt
        self.playCount = script.playCount
        self.categoryId = script.category?.id
        self.transcribedText = script.transcribedText
        self.transcriptionLanguage = script.transcriptionLanguage
    }
}

struct CategoryExport: Codable {
    let id: UUID
    let name: String
    let sortOrder: Int16
    
    init(from category: Category) {
        self.id = category.id
        self.name = category.name
        self.sortOrder = Int16(category.sortOrder)
    }
}

struct ExportSettings: Codable {
    let privacyModeDefault: Bool
    let defaultRepetitions: Int
    let defaultInterval: Double
    let defaultTranscriptionLanguage: String
    let voiceEnhancementEnabled: Bool
    let autoTrimSilence: Bool
    let silenceTrimSensitivity: String
}

struct CompleteExport: Codable {
    let manifest: ExportManifest
    let scripts: [ScriptExport]
    let categories: [CategoryExport]
}

// MARK: - Date Formatter

extension DateFormatter {
    static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter
    }()
}