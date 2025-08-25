//
//  Tag+CoreDataProperties.swift
//  Echo
//
//  Created by Assistant on 2025/08/25.
//

import Foundation
import CoreData

extension Tag {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tag> {
        return NSFetchRequest<Tag>(entityName: "Tag")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var color: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var scripts: NSSet?
    @NSManaged public var isSpecial: Bool  // For special tags like "Now"
    @NSManaged public var sortOrder: Int16  // For custom sorting
}

// MARK: Generated accessors for scripts
extension Tag {
    @objc(addScriptsObject:)
    @NSManaged public func addToScripts(_ value: SelftalkScript)
    
    @objc(removeScriptsObject:)
    @NSManaged public func removeFromScripts(_ value: SelftalkScript)
    
    @objc(addScripts:)
    @NSManaged public func addToScripts(_ values: NSSet)
    
    @objc(removeScripts:)
    @NSManaged public func removeFromScripts(_ values: NSSet)
}

// MARK: - Helper Methods
extension Tag {
    var scriptCount: Int {
        return scripts?.count ?? 0
    }
    
    static func create(name: String, color: String? = nil, isSpecial: Bool = false, sortOrder: Int16 = 999, in context: NSManagedObjectContext) -> Tag {
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = name
        tag.color = color
        tag.isSpecial = isSpecial
        tag.sortOrder = sortOrder
        tag.createdAt = Date()
        return tag
    }
    
    static func findOrCreate(name: String, in context: NSManagedObjectContext) -> Tag {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        request.fetchLimit = 1
        
        if let existingTag = try? context.fetch(request).first {
            return existingTag
        }
        
        return create(name: name, in: context)
    }
    
    // MARK: - Special "Now" Tag
    static func createOrGetNowTag(context: NSManagedObjectContext) -> Tag {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        let nowTagName = NSLocalizedString("tag.now", comment: "")
        request.predicate = NSPredicate(format: "name == %@ OR isSpecial == YES", nowTagName)
        request.fetchLimit = 1
        
        if let existingTag = try? context.fetch(request).first {
            // Update name if localization changed
            if existingTag.name != nowTagName {
                existingTag.name = nowTagName
            }
            return existingTag
        }
        
        // Create the special "Now" tag
        let nowTag = Tag.create(
            name: nowTagName,
            color: "#FFD700",  // Gold color
            isSpecial: true,
            sortOrder: 0,  // Always first
            in: context
        )
        
        do {
            try context.save()
        } catch {
            print("Failed to create Now tag: \(error)")
        }
        
        return nowTag
    }
    
    static func getNowTag(context: NSManagedObjectContext) -> Tag? {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "isSpecial == YES")
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
    
    var isNowTag: Bool {
        return isSpecial
    }
    
    static func migrateFromCategories(context: NSManagedObjectContext) {
        // Check if migration has already been done
        let tagRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        let existingTagCount = (try? context.count(for: tagRequest)) ?? 0
        
        if existingTagCount > 0 {
            print("Tags already exist, skipping migration")
            return
        }
        
        // Fetch all categories
        let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
        guard let categories = try? context.fetch(categoryRequest) else { return }
        
        // Create a tag for each category
        for category in categories {
            let tag = Tag.create(name: category.name, in: context)
            
            // Assign the tag to all scripts in this category
            if let scripts = category.scripts as? Set<SelftalkScript> {
                for script in scripts {
                    script.addToTags(tag)
                }
            }
        }
        
        // Save the context
        do {
            try context.save()
            print("Successfully migrated \(categories.count) categories to tags")
        } catch {
            print("Failed to migrate categories to tags: \(error)")
        }
    }
}

extension Tag: Identifiable {
    
}