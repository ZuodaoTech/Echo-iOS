//
//  DeduplicationService.swift
//  Echo
//
//  Service to handle deduplication of scripts after iCloud sync
//

import Foundation
import CoreData

class DeduplicationService {
    
    /// Check and remove duplicate scripts based on content
    /// This handles cases where iCloud sync creates duplicates
    static func deduplicateScripts(in context: NSManagedObjectContext) async {
        print("🔍 Starting deduplication check...")
        
        // Fetch all scripts
        let request = SelftalkScript.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SelftalkScript.createdAt, ascending: true)]
        
        do {
            let allScripts = try context.fetch(request)
            
            // Group scripts by normalized content
            var scriptGroups: [String: [SelftalkScript]] = [:]
            
            for script in allScripts {
                let key = normalizedKey(for: script)
                if scriptGroups[key] == nil {
                    scriptGroups[key] = []
                }
                scriptGroups[key]?.append(script)
            }
            
            // Process each group that has duplicates
            var duplicatesRemoved = 0
            for (key, scripts) in scriptGroups where scripts.count > 1 {
                print("  Found \(scripts.count) scripts with identical content: \(key.prefix(50))...")
                
                // Keep the oldest script (first created) or the one with audio
                let scriptsToKeep = selectScriptsToKeep(from: scripts)
                let scriptsToRemove = scripts.filter { !scriptsToKeep.contains($0) }
                
                // Merge data from duplicates into keeper
                if let keeper = scriptsToKeep.first {
                    mergeDuplicateData(from: scriptsToRemove, into: keeper)
                }
                
                // Delete duplicates
                for script in scriptsToRemove {
                    print("    ❌ Removing duplicate: ID \(script.id)")
                    context.delete(script)
                    duplicatesRemoved += 1
                }
            }
            
            if duplicatesRemoved > 0 {
                try context.save()
                print("✅ Deduplication complete: removed \(duplicatesRemoved) duplicates")
            } else {
                print("✅ No duplicates found")
            }
            
        } catch {
            print("❌ Deduplication failed: \(error)")
        }
    }
    
    /// Create a normalized key for comparing scripts
    private static func normalizedKey(for script: SelftalkScript) -> String {
        // For sample scripts, use the fixed ID
        if StaticSampleProvider.isSampleID(script.id) {
            return "sample-\(script.id.uuidString)"
        }
        
        // For user scripts, normalize the text content
        let normalizedText = script.scriptText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Include key properties in the key to avoid false positives
        return "\(normalizedText)-\(script.repetitions)-\(script.intervalSeconds)"
    }
    
    /// Select which scripts to keep from a group of duplicates
    private static func selectScriptsToKeep(from scripts: [SelftalkScript]) -> [SelftalkScript] {
        // Sort by priority: has audio > has been played > oldest
        let sorted = scripts.sorted { script1, script2 in
            // First priority: Keep scripts with audio recordings
            if script1.hasRecording && !script2.hasRecording {
                return true
            }
            if !script1.hasRecording && script2.hasRecording {
                return false
            }
            
            // Second priority: Keep scripts that have been played
            if script1.playCount > 0 && script2.playCount == 0 {
                return true
            }
            if script1.playCount == 0 && script2.playCount > 0 {
                return false
            }
            
            // Third priority: Keep sample scripts with fixed IDs
            let script1IsSample = StaticSampleProvider.isSampleID(script1.id)
            let script2IsSample = StaticSampleProvider.isSampleID(script2.id)
            if script1IsSample && !script2IsSample {
                return true
            }
            if !script1IsSample && script2IsSample {
                return false
            }
            
            // Final priority: Keep the oldest
            return script1.createdAt < script2.createdAt
        }
        
        // Return the best script
        return [sorted.first].compactMap { $0 }
    }
    
    /// Merge important data from duplicates into the keeper script
    private static func mergeDuplicateData(from duplicates: [SelftalkScript], into keeper: SelftalkScript) {
        for duplicate in duplicates {
            // Merge play count
            keeper.playCount += duplicate.playCount
            
            // Keep the most recent play date
            if let duplicatePlayDate = duplicate.lastPlayedAt,
               keeper.lastPlayedAt == nil || duplicatePlayDate > keeper.lastPlayedAt! {
                keeper.lastPlayedAt = duplicatePlayDate
            }
            
            // Keep audio recording if keeper doesn't have one
            if !keeper.hasRecording && duplicate.hasRecording {
                keeper.audioFilePath = duplicate.audioFilePath
                keeper.audioDuration = duplicate.audioDuration
            }
            
            // Merge transcription if keeper doesn't have one
            if keeper.transcribedText == nil && duplicate.transcribedText != nil {
                keeper.transcribedText = duplicate.transcribedText
                keeper.transcriptionLanguage = duplicate.transcriptionLanguage
            }
            
            // Keep notification settings if enabled
            if !keeper.notificationEnabled && duplicate.notificationEnabled {
                keeper.notificationEnabled = duplicate.notificationEnabled
                keeper.notificationFrequency = duplicate.notificationFrequency
                keeper.notificationEnabledAt = duplicate.notificationEnabledAt
            }
            
            // Merge tags
            if let duplicateTags = duplicate.tags {
                keeper.addToTags(duplicateTags)
            }
        }
        
        // Update the modification date
        keeper.updatedAt = Date()
    }
    
    /// Check if deduplication is needed (called on app launch)
    static func shouldCheckForDuplicates() -> Bool {
        // Check if we've recently run deduplication
        let lastCheckKey = "lastDeduplicationCheck"
        let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? Date.distantPast
        let hoursSinceLastCheck = Date().timeIntervalSince(lastCheck) / 3600
        
        // Only check once per hour to avoid performance impact
        return hoursSinceLastCheck > 1
    }
    
    /// Mark that deduplication has been performed
    static func markDeduplicationComplete() {
        UserDefaults.standard.set(Date(), forKey: "lastDeduplicationCheck")
    }
}