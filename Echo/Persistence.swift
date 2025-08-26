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
    
    // Track if Core Data is ready
    @Published var isReady = false
    
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews using Tags
        let nowTag = Tag.createOrGetNowTag(context: viewContext)
        
        let breakingBadHabitsTag = Tag.create(
            name: NSLocalizedString("tag.breaking_bad_habits", comment: ""),
            in: viewContext
        )
        
        let buildingGoodHabitsTag = Tag.create(
            name: NSLocalizedString("tag.building_good_habits", comment: ""),
            in: viewContext
        )
        
        let appropriatePositivityTag = Tag.create(
            name: NSLocalizedString("tag.appropriate_positivity", comment: ""),
            in: viewContext
        )
        
        // Create sample scripts
        let script1 = SelftalkScript.create(
            scriptText: NSLocalizedString("sample.smoking", comment: ""),
            repetitions: 3,
            privateMode: true,
            in: viewContext
        )
        script1.addToTags(nowTag)
        script1.addToTags(breakingBadHabitsTag)
        
        let script2 = SelftalkScript.create(
            scriptText: NSLocalizedString("sample.bedtime", comment: ""),
            repetitions: 3,
            privateMode: true,
            in: viewContext
        )
        script2.addToTags(nowTag)
        script2.addToTags(buildingGoodHabitsTag)
        
        let script3 = SelftalkScript.create(
            scriptText: NSLocalizedString("sample.mistakes", comment: ""),
            repetitions: 3,
            privateMode: true,
            in: viewContext
        )
        script3.addToTags(nowTag)
        script3.addToTags(appropriatePositivityTag)
        
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
        
        // Load stores asynchronously to not block app launch
        Task {
            await loadStores(inMemory: inMemory, iCloudEnabled: UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true)
        }
    }
    
    private func loadStores(inMemory: Bool, iCloudEnabled: Bool) async {
        await withCheckedContinuation { continuation in
            container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("Core Data error: \(error), \(error.userInfo)")
                
                // If CloudKit fails or store fails to load, try local storage only
                if error.domain == CKErrorDomain || error.code == 134060 || error.code == 134110 {
                    print("CloudKit/Store error detected, attempting fallback to local storage")
                    
                    // Don't automatically disable iCloud sync preference - let user control it
                    // The error is due to Core Data model constraints, not user preference
                    // UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")
                    
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
            
            // Mark as ready and continue
            DispatchQueue.main.async {
                self.isReady = true
                // Track Core Data ready time
                AppLaunchOptimizer.LaunchMetrics.coreDataReady = Date()
            }
            continuation.resume()
        })
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Create the special "Now" tag after stores are loaded
        Task { @MainActor in
            // Wait for stores to be ready
            while !isReady {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
            _ = Tag.createOrGetNowTag(context: self.container.viewContext)
            
            // Set up CloudKit schema initialization only if CloudKit is enabled and in DEBUG
            #if DEBUG
            if iCloudEnabled && !self.container.persistentStoreCoordinator.persistentStores.isEmpty {
                do {
                    try self.container.initializeCloudKitSchema()
                    print("CloudKit schema initialized successfully")
                } catch {
                    print("CloudKit schema initialization error: \(error)")
                }
            }
            #endif
        }
    }
}