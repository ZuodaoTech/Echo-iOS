//
//  StaticSampleCard.swift
//  Echo
//
//  Static sample cards for instant display on first launch
//

import Foundation

/// Lightweight model for displaying sample cards before Core Data is ready
struct StaticSampleCard: Identifiable {
    let id: UUID
    let scriptText: String
    let category: String
    let repetitions: Int
    let intervalSeconds: Double
    
    /// Fixed UUIDs for sample cards to enable deduplication
    static let smokingSampleID: UUID = {
        guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000001") else {
            SecureLogger.error("Failed to create smoking sample UUID, using random UUID")
            return UUID()
        }
        return uuid
    }()
    
    static let bedtimeSampleID: UUID = {
        guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000002") else {
            SecureLogger.error("Failed to create bedtime sample UUID, using random UUID")
            return UUID()
        }
        return uuid
    }()
    
    static let mistakesSampleID: UUID = {
        guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000003") else {
            SecureLogger.error("Failed to create mistakes sample UUID, using random UUID")
            return UUID()
        }
        return uuid
    }()
}

/// Provider for static sample cards
class StaticSampleProvider {
    static let shared = StaticSampleProvider()
    
    private init() {}
    
    /// Cache to avoid recreating samples
    private var cachedSamples: [StaticSampleCard]?
    
    /// Get sample cards in the user's current language
    func getSamples() -> [StaticSampleCard] {
        // Return cached if available
        if let cached = cachedSamples {
            return cached
        }
        
        // Create samples using existing localizations
        let samples = [
            StaticSampleCard(
                id: StaticSampleCard.smokingSampleID,
                scriptText: NSLocalizedString("sample.smoking", comment: ""),
                category: NSLocalizedString("tag.breaking_bad_habits", comment: ""),
                repetitions: 3,
                intervalSeconds: 1.0
            ),
            StaticSampleCard(
                id: StaticSampleCard.bedtimeSampleID,
                scriptText: NSLocalizedString("sample.bedtime", comment: ""),
                category: NSLocalizedString("tag.building_good_habits", comment: ""),
                repetitions: 3,
                intervalSeconds: 1.0
            ),
            StaticSampleCard(
                id: StaticSampleCard.mistakesSampleID,
                scriptText: NSLocalizedString("sample.mistakes", comment: ""),
                category: NSLocalizedString("tag.appropriate_positivity", comment: ""),
                repetitions: 3,
                intervalSeconds: 1.0
            )
        ]
        
        cachedSamples = samples
        return samples
    }
    
    /// Clear cache when language changes
    func clearCache() {
        cachedSamples = nil
    }
    
    /// Check if a script ID is a sample
    static func isSampleID(_ id: UUID) -> Bool {
        return id == StaticSampleCard.smokingSampleID || 
               id == StaticSampleCard.bedtimeSampleID || 
               id == StaticSampleCard.mistakesSampleID
    }
}