//
//  ExportModels.swift
//  Echo
//
//  Models for export/import functionality
//

import Foundation
import UIKit

// MARK: - Export Models

/// Root structure for backup file
struct BackupData: Codable {
    let metadata: BackupMetadata
    let scripts: [ExportableScript]
    let tags: [ExportableTag]
    
    enum CodingKeys: String, CodingKey {
        case metadata
        case scripts
        case tags
    }
}

/// Metadata about the backup
struct BackupMetadata: Codable {
    let version: String
    let appVersion: String
    let createdAt: Date
    let deviceName: String
    let locale: String
    var statistics: BackupStatistics
    var exportOptions: ExportOptions
    
    enum CodingKeys: String, CodingKey {
        case version
        case appVersion = "app_version"
        case createdAt = "created_at"
        case deviceName = "device_name"
        case locale
        case statistics
        case exportOptions = "export_options"
    }
    
    init() {
        self.version = "1.0"
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        self.createdAt = Date()
        self.deviceName = UIDevice.current.name
        self.locale = Locale.current.identifier
        self.statistics = BackupStatistics()
        self.exportOptions = ExportOptions()
    }
}

/// Statistics about the backup content
struct BackupStatistics: Codable {
    var totalScripts: Int = 0
    var totalRecordings: Int = 0
    var totalAudioSizeMB: Double = 0
    var totalPlayCount: Int = 0
    
    enum CodingKeys: String, CodingKey {
        case totalScripts = "total_scripts"
        case totalRecordings = "total_recordings"
        case totalAudioSizeMB = "total_audio_size_mb"
        case totalPlayCount = "total_play_count"
    }
}

/// Export options used
struct ExportOptions: Codable {
    var includeAudio: Bool = true
    var includeStats: Bool = true
    var includeDeleted: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case includeAudio = "include_audio"
        case includeStats = "include_stats"
        case includeDeleted = "include_deleted"
    }
}

/// Exportable version of SelftalkScript
struct ExportableScript: Codable {
    let id: UUID
    let scriptText: String
    let repetitions: Int16
    let intervalSeconds: Double
    let privacyMode: Bool
    let createdAt: Date
    let updatedAt: Date
    let playCount: Int32
    let lastPlayedAt: Date?
    let audio: AudioInfo?
    let transcription: TranscriptionInfo?
    let tagNames: [String]
    let isSystemSample: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case scriptText = "script_text"
        case repetitions
        case intervalSeconds = "interval_seconds"
        case privacyMode = "privacy_mode"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case playCount = "play_count"
        case lastPlayedAt = "last_played_at"
        case audio
        case transcription
        case tagNames = "tags"
        case isSystemSample = "is_system_sample"
    }
    
    /// Create from Core Data entity
    init(from script: SelftalkScript) {
        self.id = script.id
        self.scriptText = script.scriptText
        self.repetitions = script.repetitions
        self.intervalSeconds = script.intervalSeconds
        self.privacyMode = script.privateModeEnabled
        self.createdAt = script.createdAt
        self.updatedAt = script.updatedAt
        self.playCount = script.playCount
        self.lastPlayedAt = script.lastPlayedAt
        
        // Audio info
        if let audioPath = script.audioFilePath {
            let url = URL(fileURLWithPath: audioPath)
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: audioPath)[.size] as? Int) ?? 0
            
            self.audio = AudioInfo(
                filename: url.lastPathComponent,
                duration: script.audioDuration,
                sizeBytes: fileSize,
                checksum: nil // Will be calculated during export
            )
        } else {
            self.audio = nil
        }
        
        // Transcription info
        if let transcribedText = script.transcribedText {
            self.transcription = TranscriptionInfo(
                text: transcribedText,
                language: script.transcriptionLanguage ?? "en-US",
                confidence: nil
            )
        } else {
            self.transcription = nil
        }
        
        // Tags
        self.tagNames = script.tagsArray.map { $0.name }
        
        // Check if it's a system sample
        self.isSystemSample = StaticSampleProvider.isSampleID(script.id)
    }
}

/// Audio file information
struct AudioInfo: Codable {
    let filename: String
    let duration: Double
    let sizeBytes: Int
    let checksum: String?
    
    enum CodingKeys: String, CodingKey {
        case filename
        case duration
        case sizeBytes = "size_bytes"
        case checksum
    }
}

/// Transcription information
struct TranscriptionInfo: Codable {
    let text: String
    let language: String
    let confidence: Double?
}

/// Exportable version of Tag
struct ExportableTag: Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt = "created_at"
    }
    
    init(from tag: Tag) {
        self.id = tag.id
        self.name = tag.name
        self.createdAt = tag.createdAt
    }
}

// MARK: - Import Models

/// Result of import validation
struct ImportValidation {
    let isValid: Bool
    let errors: [ImportError]
    let warnings: [ImportWarning]
    let backupInfo: BackupMetadata?
}

/// Import error types
enum ImportError: LocalizedError {
    case invalidFormat(String)
    case incompatibleVersion(String, String)
    case corruptedData(String)
    case missingRequiredFile(String)
    case insufficientSpace(required: Int64, available: Int64)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat(let detail):
            return "Invalid backup format: \(detail)"
        case .incompatibleVersion(let required, let current):
            return "Incompatible version. Requires \(required), current: \(current)"
        case .corruptedData(let detail):
            return "Corrupted backup data: \(detail)"
        case .missingRequiredFile(let filename):
            return "Missing required file: \(filename)"
        case .insufficientSpace(let required, let available):
            let requiredMB = Double(required) / 1_048_576
            let availableMB = Double(available) / 1_048_576
            return String(format: "Insufficient space. Need %.1fMB, available %.1fMB", requiredMB, availableMB)
        }
    }
}

/// Import warning types
enum ImportWarning {
    case missingAudioFile(scriptId: UUID, filename: String)
    case duplicateScript(scriptId: UUID, title: String)
    case futureVersion(version: String)
}

/// Import conflict resolution
enum ImportConflictResolution {
    case keepExisting      // Skip if script exists
    case replaceExisting   // Overwrite with imported
    case mergeDuplicate    // Create new with suffix
    case smartMerge        // Compare timestamps, keep newer
}

/// Import preview information
struct ImportPreview {
    let backupMetadata: BackupMetadata
    let scriptsToImport: Int
    let scriptsToUpdate: Int
    let scriptsToSkip: Int
    let newTags: Int
    let conflicts: [ImportConflict]
    let estimatedSize: Int64
}

/// Import conflict detail
struct ImportConflict {
    let imported: ExportableScript
    let existing: SelftalkScript
    let reason: ConflictReason
    
    enum ConflictReason: Equatable {
        case sameID
        case similarContent(similarity: Double)
    }
}

/// Import result
struct ImportResult {
    let imported: Int
    let updated: Int
    let skipped: Int
    let failed: [(script: ExportableScript, error: Error)]
    
    var message: String {
        var parts: [String] = []
        
        if imported > 0 {
            parts.append("✅ Imported: \(imported) new scripts")
        }
        if updated > 0 {
            parts.append("🔄 Updated: \(updated) existing scripts")
        }
        if skipped > 0 {
            parts.append("⏭️ Skipped: \(skipped) duplicates")
        }
        if !failed.isEmpty {
            parts.append("❌ Failed: \(failed.count)")
        }
        
        return parts.isEmpty ? "No changes made" : parts.joined(separator: "\n")
    }
}