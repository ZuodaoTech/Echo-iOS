import Foundation
import CoreData

extension Category {
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
    
    static func createDefaultCategories(context: NSManagedObjectContext) {
        let defaultCategories = [
            "Breaking Bad Habits",
            "Building Good Habits", 
            "Appropriate Positivity",
            "Personal",
            "Work"
        ]
        
        for (index, name) in defaultCategories.enumerated() {
            let category = Category(context: context)
            category.id = UUID()
            category.name = name
            category.createdAt = Date()
            category.sortOrder = Int32(index)
        }
        
        try? context.save()
    }
}