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
        
        // Create sample scripts with localized content
        let categories = try? viewContext.fetch(Category.fetchRequest())
        let localizedScripts = LocalizationHelper.shared.getLocalizedSampleScripts()
        
        if let breakingBadHabits = categories?.first(where: { $0.nameKey == "category.breaking_bad_habits" }) {
            if let scriptText = localizedScripts.first(where: { $0.category == "category.breaking_bad_habits" })?.text {
                _ = SelftalkScript.create(
                    scriptText: scriptText,
                    category: breakingBadHabits,
                    repetitions: 3,
                    privacyMode: true,
                    in: viewContext
                )
            }
        }
        
        if let buildingGoodHabits = categories?.first(where: { $0.nameKey == "category.building_good_habits" }) {
            if let scriptText = localizedScripts.first(where: { $0.category == "category.building_good_habits" })?.text {
                _ = SelftalkScript.create(
                    scriptText: scriptText,
                    category: buildingGoodHabits,
                    repetitions: 3,
                    privacyMode: true,
                    in: viewContext
                )
            }
        }
        
        if let appropriatePositivity = categories?.first(where: { $0.nameKey == "category.appropriate_positivity" }) {
            if let scriptText = localizedScripts.first(where: { $0.category == "category.appropriate_positivity" })?.text {
                _ = SelftalkScript.create(
                    scriptText: scriptText,
                    category: appropriatePositivity,
                    repetitions: 3,
                    privacyMode: true,
                    in: viewContext
                )
            }
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
    
    // Track iCloud sync status (default to true)
    @Published var iCloudSyncEnabled: Bool = {
        if UserDefaults.standard.object(forKey: "iCloudSyncEnabled") == nil {
            // First time - set default to true
            UserDefaults.standard.set(true, forKey: "iCloudSyncEnabled")
            return true
        }
        return UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
    }()

    init(inMemory: Bool = false) {
        // Use NSPersistentCloudKitContainer for CloudKit support
        container = NSPersistentCloudKitContainer(name: "Echo")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure for CloudKit if enabled (default to true)
            let iCloudEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
            
            container.persistentStoreDescriptions.forEach { storeDescription in
                // Always enable history tracking to avoid read-only mode
                storeDescription.setOption(true as NSNumber, 
                                          forKey: NSPersistentHistoryTrackingKey)
                storeDescription.setOption(true as NSNumber, 
                                          forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                
                if iCloudEnabled {
                    // Set CloudKit container options
                    storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                        containerIdentifier: "iCloud.xiaolai.Echo"
                    )
                    
                    // Allow public database for sharing (future feature)
                    storeDescription.cloudKitContainerOptions?.databaseScope = .private
                } else {
                    // Disable CloudKit but keep history tracking
                    storeDescription.cloudKitContainerOptions = nil
                }
            }
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("Core Data error: \(error), \(error.userInfo)")
                
                // If CloudKit fails or store fails to load, try local storage only
                if error.domain == CKErrorDomain || error.code == 134060 || error.code == 134110 {
                    print("CloudKit/Store error detected, attempting fallback to local storage")
                    
                    // Reset to use local storage only
                    UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")
                    
                    // Reconfigure for local storage only but keep history tracking
                    for description in self.container.persistentStoreDescriptions {
                        description.cloudKitContainerOptions = nil
                        // Ensure history tracking remains enabled
                        description.setOption(true as NSNumber, 
                                             forKey: NSPersistentHistoryTrackingKey)
                        description.setOption(true as NSNumber, 
                                             forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                    }
                    
                    // Try loading stores again without CloudKit
                    self.container.loadPersistentStores { (retryDescription, retryError) in
                        if let retryError = retryError as NSError? {
                            // If still failing, this is a critical error
                            fatalError("Unable to load persistent stores: \(retryError), \(retryError.userInfo)")
                        } else {
                            print("Successfully loaded local persistent store after CloudKit failure")
                        }
                    }
                } else {
                    // For other errors, still try to continue but log the issue
                    print("Core Data warning: Store loaded with error, app may have limited functionality")
                }
            } else {
                print("Core Data: Successfully loaded persistent store")
                print("Store type: \(storeDescription.type)")
                print("Store URL: \(storeDescription.url?.absoluteString ?? "nil")")
                print("CloudKit enabled: \(storeDescription.cloudKitContainerOptions != nil)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Migrate categories to tags if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            Tag.migrateFromCategories(context: self.container.viewContext)
            // Create the special "Now" tag if it doesn't exist
            _ = Tag.createOrGetNowTag(context: self.container.viewContext)
        }
        
        // Set up CloudKit schema initialization only if CloudKit is enabled and in DEBUG
        #if DEBUG
        let cloudKitEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        if cloudKitEnabled {
            // Delay schema initialization to ensure stores are loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                do {
                    // Only initialize if we have persistent stores
                    if !self.container.persistentStoreCoordinator.persistentStores.isEmpty {
                        try self.container.initializeCloudKitSchema()
                        print("CloudKit schema initialized successfully")
                    }
                } catch {
                    print("CloudKit schema initialization error: \(error)")
                }
            }
        }
        #endif
    }
}