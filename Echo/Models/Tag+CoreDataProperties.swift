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
    
    static func create(name: String, color: String? = nil, sortOrder: Int16 = 999, in context: NSManagedObjectContext) -> Tag {
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = name
        tag.color = color
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
    
    // Enhanced method to prevent duplicates with case-insensitive and trimmed comparison
    static func findOrCreateNormalized(name: String, in context: NSManagedObjectContext) -> Tag {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            // Return or create a default "Untagged" tag for empty names
            return findOrCreate(name: "Untagged", in: context)
        }
        
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        // Case-insensitive comparison with trimmed name
        request.predicate = NSPredicate(format: "name ==[c] %@", trimmedName)
        request.fetchLimit = 1
        
        if let existingTag = try? context.fetch(request).first {
            return existingTag
        }
        
        // Create with trimmed name
        return create(name: trimmedName, in: context)
    }
    
    // MARK: - Duplicate Cleanup
    static func cleanupDuplicateTags(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        guard let allTags = try? context.fetch(request) else {
            #if DEBUG
            print("Failed to fetch tags for cleanup")
            #endif
            return
        }
        
        // Group tags by normalized name
        var tagsByNormalizedName: [String: [Tag]] = [:]
        
        for tag in allTags {
            let normalized = tag.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            
            tagsByNormalizedName[normalized, default: []].append(tag)
        }
        
        var mergeCount = 0
        
        // Merge duplicates
        for (normalizedName, tags) in tagsByNormalizedName where tags.count > 1 {
            #if DEBUG
            print("Found \(tags.count) duplicate tags for '\(normalizedName)'")
            #endif
            
            // Keep the first (oldest) tag
            let keepTag = tags[0]
            
            // Merge scripts from duplicate tags
            for duplicateTag in tags.dropFirst() {
                if let scripts = duplicateTag.scripts {
                    keepTag.addToScripts(scripts)
                    #if DEBUG
                    print("  Merging scripts from '\(duplicateTag.name)' to '\(keepTag.name)'")
                    #endif
                }
                context.delete(duplicateTag)
                mergeCount += 1
            }
        }
        
        if mergeCount > 0 {
            #if DEBUG
            print("Cleaned up \(mergeCount) duplicate tags")
            #endif
            do {
                try context.save()
                #if DEBUG
                print("Successfully saved tag cleanup")
                #endif
            } catch {
                #if DEBUG
                print("Failed to save tag cleanup: \(error)")
                #endif
            }
        } else {
            #if DEBUG
            print("No duplicate tags found")
            #endif
        }
    }
    
}

extension Tag: Identifiable {
    
}