import Foundation
import CoreData

extension Category {
    
    // Store a key instead of localized name
    var localizedName: String {
        // If this is a system category, use its localization key
        if let nameKey = self.nameKey {
            return NSLocalizedString(nameKey, comment: "")
        }
        // For user-created categories, return the actual name
        return self.name
    }
    
    // Check if this is a system category
    var isSystemCategory: Bool {
        return nameKey != nil
    }
}

// Add nameKey property to Category entity for storing localization keys
// This should be added to the Core Data model as an optional String attribute