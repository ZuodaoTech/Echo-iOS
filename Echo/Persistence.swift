//
//  Persistence.swift
//  Echo
//
//  Created by joker on 8/23/25.
//

import CoreData
import CloudKit
import Combine

class PersistenceController: ObservableObject {
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

    let container: NSPersistentCloudKitContainer
    
    // Track iCloud sync status
    @Published var iCloudSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")

    init(inMemory: Bool = false) {
        // Use NSPersistentCloudKitContainer for CloudKit support
        container = NSPersistentCloudKitContainer(name: "Echo")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure for CloudKit if enabled
            let iCloudEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
            
            container.persistentStoreDescriptions.forEach { storeDescription in
                if iCloudEnabled {
                    // Enable CloudKit sync
                    storeDescription.setOption(true as NSNumber, 
                                              forKey: NSPersistentHistoryTrackingKey)
                    storeDescription.setOption(true as NSNumber, 
                                              forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                    
                    // Set CloudKit container options
                    storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                        containerIdentifier: "iCloud.xiaolai.Echo"
                    )
                    
                    // Allow public database for sharing (future feature)
                    storeDescription.cloudKitContainerOptions?.databaseScope = .private
                } else {
                    // Disable CloudKit
                    storeDescription.cloudKitContainerOptions = nil
                }
            }
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Don't crash the app if CloudKit fails, just log the error
                print("Core Data error: \(error), \(error.userInfo)")
                
                // If CloudKit fails, fall back to local storage
                if error.domain == CKErrorDomain {
                    print("CloudKit error detected, falling back to local storage")
                    UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")
                }
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Set up CloudKit schema initialization (only needed once)
        #if DEBUG
        do {
            try container.initializeCloudKitSchema()
        } catch {
            print("CloudKit schema initialization error: \(error)")
        }
        #endif
    }
}