//
//  Persistence.swift
//  Echo
//
//  Created by joker on 8/23/25.
//

import CoreData
import CloudKit
import Combine
import SwiftUI

class PersistenceController: ObservableObject {
    // Singleton instance - ensure only one Core Data stack
    static let shared: PersistenceController = {
        let instance = PersistenceController()
        return instance
    }()
    
    // Track if Core Data is ready
    @Published var isReady = false
    
    // Track the current data loading state for UI
    @Published var dataLoadingState: DataLoadingState = .staticSamples
    
    // Only create preview controller when actually in preview mode
    @MainActor
    static var preview: PersistenceController = {
        #if DEBUG
        // Guard against creating preview outside of SwiftUI previews
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" else {
            // Return shared instance if not in preview
            return PersistenceController.shared
        }
        #endif
        
        let result = PersistenceController(inMemory: true)
        
        // Only create sample data in DEBUG builds to avoid overhead
        #if DEBUG
        let viewContext = result.container.viewContext
        
        // Create minimal sample data for previews using Tags
        let breakingBadHabitsTag = Tag.findOrCreateNormalized(
            name: "Breaking Bad Habits",
            in: viewContext
        )
        
        // Create a single sample script
        let script1 = SelftalkScript.create(
            scriptText: "I never smoke, because it stinks, and I hate being controlled.",
            repetitions: 3,
            privateMode: true,
            in: viewContext
        )
        script1.addToTags(breakingBadHabitsTag)
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Preview data error: \(nsError), \(nsError.userInfo)")
        }
        #endif
        
        return result
    }()

    let container: NSPersistentCloudKitContainer
    
    // Track iCloud sync status (default to false for fresh installs)
    @Published var iCloudSyncEnabled: Bool = {
        if UserDefaults.standard.object(forKey: "iCloudSyncEnabled") == nil {
            // First time - set default to false (disabled)
            UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")
            return false
        }
        return UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
    }()

    private static var hasInitialized = false
    
    init(inMemory: Bool = false) {
        // Prevent multiple Core Data stacks
        if !inMemory && Self.hasInitialized {
            fatalError("PersistenceController should only be initialized once. Use .shared instance.")
        }
        if !inMemory {
            Self.hasInitialized = true
        }
        
        // Use NSPersistentCloudKitContainer for CloudKit support
        container = NSPersistentCloudKitContainer(name: "Echo")
        
        if inMemory {
            if let firstDescription = container.persistentStoreDescriptions.first {
                firstDescription.url = URL(fileURLWithPath: "/dev/null")
            }
        } else {
            // Configure for CloudKit if enabled (default to false for fresh installs)
            let iCloudEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? false
            
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
        
        // Load stores asynchronously with high priority for first launch
        Task(priority: .high) {
            await loadStores(inMemory: inMemory, iCloudEnabled: UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? false)
        }
    }
    
    private func loadStores(inMemory: Bool, iCloudEnabled: Bool) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
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
            
            // Mark as ready and check if we need to import samples
            DispatchQueue.main.async {
                self.isReady = true
                // Track Core Data ready time
                AppLaunchOptimizer.LaunchMetrics.coreDataReady = Date()
                
                // Transition to Core Data state
                self.dataLoadingState = .transitioningToCore
                
                // Check if we need to import samples
                Task { @MainActor in
                    await self.importSamplesIfNeeded()
                    
                    // Final transition to ready state
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.dataLoadingState = .coreDataReady
                    }
                }
            }
            continuation.resume()
        })
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Defer CloudKit schema initialization to after launch
        #if DEBUG
        Task(priority: .background) { @MainActor in
            // Wait a bit after launch to initialize CloudKit schema
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            
            // Wait for stores to be ready
            while !isReady {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
            
            if iCloudEnabled && !self.container.persistentStoreCoordinator.persistentStores.isEmpty {
                do {
                    try self.container.initializeCloudKitSchema()
                    print("CloudKit schema initialized successfully")
                } catch {
                    print("CloudKit schema initialization error: \(error)")
                }
            }
        }
        #endif
    }
    
    // MARK: - Sample Data Import
    
    /// Import sample cards if this is a fresh install
    @MainActor
    private func importSamplesIfNeeded() async {
        let context = container.viewContext
        
        // Check if we have any existing scripts
        let request = SelftalkScript.fetchRequest()
        let existingCount = (try? context.count(for: request)) ?? 0
        
        // If we have existing data, skip samples
        guard existingCount == 0 else {
            print("Found \(existingCount) existing scripts, skipping sample import")
            return
        }
        
        print("No existing scripts found, importing samples...")
        
        // Get static samples
        let samples = StaticSampleProvider.shared.getSamples()
        
        for sample in samples {
            // Check if sample already exists (by ID)
            let fetchRequest = SelftalkScript.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", sample.id as CVarArg)
            fetchRequest.fetchLimit = 1
            
            let existing = try? context.fetch(fetchRequest).first
            guard existing == nil else {
                print("Sample \(sample.id) already exists, skipping")
                continue
            }
            
            // Find or create the category/tag
            let tag = Tag.findOrCreateNormalized(
                name: sample.category,
                in: context
            )
            
            // Create the script
            let script = SelftalkScript.create(
                scriptText: sample.scriptText,
                repetitions: Int16(sample.repetitions),
                privateMode: true,
                in: context
            )
            
            // Use the fixed sample ID for deduplication
            script.id = sample.id
            script.intervalSeconds = sample.intervalSeconds
            script.addToTags(tag)
            
            print("Created sample script: \(sample.category)")
        }
        
        // Save the context
        do {
            try context.save()
            print("Successfully imported \(samples.count) sample scripts")
        } catch {
            print("Failed to save sample scripts: \(error)")
        }
    }
}