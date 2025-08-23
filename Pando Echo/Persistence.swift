//
//  Persistence.swift
//  Pando Echo
//
//  Created by joker on 8/23/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews
        Category.createDefaultCategories(context: viewContext)
        
        // Create sample scripts
        let categories = try? viewContext.fetch(Category.fetchRequest())
        
        if let breakingBadHabits = categories?.first(where: { $0.name == "Breaking Bad Habits" }) {
            _ = SelftalkScript.create(
                scriptText: "I never smoke, because it stinks, and I hate being controlled.",
                category: breakingBadHabits,
                repetitions: 3,
                privacyMode: true,
                in: viewContext
            )
        }
        
        if let buildingGoodHabits = categories?.first(where: { $0.name == "Building Good Habits" }) {
            _ = SelftalkScript.create(
                scriptText: "I always go to bed before 10 p.m., because it's healthier, and I love waking up with a great deal of energy.",
                category: buildingGoodHabits,
                repetitions: 3,
                privacyMode: true,
                in: viewContext
            )
        }
        
        if let appropriatePositivity = categories?.first(where: { $0.name == "Appropriate Positivity" }) {
            _ = SelftalkScript.create(
                scriptText: "I made a few mistakes, but I also did several things well. Mistakes are a normal part of learning, and I can use them as an opportunity to improve.",
                category: appropriatePositivity,
                repetitions: 3,
                privacyMode: true,
                in: viewContext
            )
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Pando_Echo")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}