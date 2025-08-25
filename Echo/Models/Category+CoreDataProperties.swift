import Foundation
import CoreData

extension Category: Identifiable {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Category> {
        return NSFetchRequest<Category>(entityName: "Category")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var nameKey: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var sortOrder: Int32
    @NSManaged public var scripts: NSSet?
}

// MARK: Generated accessors for scripts
extension Category {
    @objc(addScriptsObject:)
    @NSManaged public func addToScripts(_ value: SelftalkScript)
    
    @objc(removeScriptsObject:)
    @NSManaged public func removeFromScripts(_ value: SelftalkScript)
    
    @objc(addScripts:)
    @NSManaged public func addToScripts(_ values: NSSet)
    
    @objc(removeScripts:)
    @NSManaged public func removeFromScripts(_ values: NSSet)
}

extension Category {
    public var scriptsArray: [SelftalkScript] {
        let set = scripts as? Set<SelftalkScript> ?? []
        return set.sorted { $0.createdAt < $1.createdAt }
    }
    
    static func removeDuplicateCategories(context: NSManagedObjectContext) {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.createdAt, ascending: true)]
        
        do {
            let categories = try context.fetch(request)
            var seenNames = Set<String>()
            var toDelete: [Category] = []
            
            for category in categories {
                if seenNames.contains(category.name) {
                    // This is a duplicate, mark for deletion
                    // Keep the oldest one (first occurrence)
                    toDelete.append(category)
                    print("Found duplicate category: \(category.name)")
                } else {
                    seenNames.insert(category.name)
                }
            }
            
            // Delete duplicates
            for category in toDelete {
                context.delete(category)
            }
            
            if !toDelete.isEmpty {
                try context.save()
                print("Removed \(toDelete.count) duplicate categories")
            }
        } catch {
            print("Error removing duplicate categories: \(error)")
        }
    }
    
    static func createDefaultCategories(context: NSManagedObjectContext) {
        let defaultCategories = [
            (key: "category.breaking_bad_habits", fallbackName: "Breaking Bad Habits"),
            (key: "category.building_good_habits", fallbackName: "Building Good Habits"),
            (key: "category.appropriate_positivity", fallbackName: "Appropriate Positivity")
        ]
        
        // First, remove any duplicates
        removeDuplicateCategories(context: context)
        
        // Check if categories already exist based on nameKey
        for categoryData in defaultCategories {
            let request: NSFetchRequest<Category> = Category.fetchRequest()
            request.predicate = NSPredicate(format: "nameKey == %@", categoryData.key)
            
            if let existingCategories = try? context.fetch(request), !existingCategories.isEmpty {
                continue // Skip if already exists
            }
            
            let category = Category(context: context)
            category.id = UUID()
            category.nameKey = categoryData.key
            category.name = NSLocalizedString(categoryData.key, comment: "")
            // Fallback to English if localization not available
            if category.name == categoryData.key {
                category.name = categoryData.fallbackName
            }
            category.createdAt = Date()
            category.sortOrder = Int32(defaultCategories.firstIndex(where: { $0.key == categoryData.key }) ?? 0)
        }
        
        try? context.save()
        print("Created default categories with localization support")
    }
}