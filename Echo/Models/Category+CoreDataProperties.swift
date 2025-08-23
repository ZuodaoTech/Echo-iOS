import Foundation
import CoreData

extension Category: Identifiable {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Category> {
        return NSFetchRequest<Category>(entityName: "Category")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var name: String
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
            "Breaking Bad Habits",
            "Building Good Habits", 
            "Appropriate Positivity",
            "Personal",
            "Work"
        ]
        
        // First, remove any duplicates
        removeDuplicateCategories(context: context)
        
        // Check if categories already exist
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        let existingCount = (try? context.count(for: request)) ?? 0
        
        // Only create if no categories exist
        guard existingCount == 0 else { 
            print("Categories already exist, skipping creation")
            return 
        }
        
        for (index, name) in defaultCategories.enumerated() {
            let category = Category(context: context)
            category.id = UUID()
            category.name = name
            category.createdAt = Date()
            category.sortOrder = Int32(index)
        }
        
        try? context.save()
        print("Created \(defaultCategories.count) default categories")
    }
}