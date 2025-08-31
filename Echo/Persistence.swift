//
//  Persistence.swift
//  Echo
//
//  Created by joker on 8/23/25.
//

import CoreData
import Combine
import SwiftUI

class PersistenceController: ObservableObject {
    // Lazy singleton - only created when first accessed
    private static var _shared: PersistenceController?
    
    static var shared: PersistenceController {
        if _shared == nil {
            _shared = PersistenceController()
        }
        return _shared!
    }
    
    // Check if shared exists without creating it
    static func getSharedIfExists() throws -> PersistenceController? {
        return _shared
    }
    
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

    private var _container: NSPersistentContainer?
    private var isInMemory: Bool = false
    
    var container: NSPersistentContainer {
        if _container == nil {
            // Lazy create container only when needed
            _container = NSPersistentContainer(name: "Echo")
            configureContainer()
        }
        return _container!
    }
    
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
        
        self.isInMemory = inMemory
        // Don't create container here - it will be created lazily when accessed
    }
    
    private func configureContainer() {
        guard let container = _container else { return }
        
        if isInMemory {
            if let firstDescription = container.persistentStoreDescriptions.first {
                firstDescription.url = URL(fileURLWithPath: "/dev/null")
            }
        } else {
            // Configure for local storage only
            container.persistentStoreDescriptions.forEach { storeDescription in
                // Enable history tracking for potential future features
                storeDescription.setOption(true as NSNumber, 
                                          forKey: NSPersistentHistoryTrackingKey)
                storeDescription.setOption(true as NSNumber, 
                                          forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            }
        }
    }
    
    func loadStores(inMemory: Bool) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("Core Data error: \(error), \(error.userInfo)")
                
                // Try to handle common errors gracefully
                if error.code == 134110 { // Model version mismatch
                    print("Core Data model version mismatch - attempting migration")
                    // In production, you might want to attempt lightweight migration
                    // For now, we'll log and continue with limited functionality
                    print("WARNING: App may have limited functionality due to Core Data error")
                } else if error.code == 134060 { // Store file issue
                    print("Core Data store file issue - app will continue with limited functionality")
                } else {
                    // For truly unrecoverable errors, we still need to fail
                    print("CRITICAL: Unrecoverable Core Data error")
                    fatalError("Unable to load persistent stores: \(error), \(error.userInfo)")
                }
            } else {
                print("Core Data: Successfully loaded persistent store")
                print("Store type: \(storeDescription.type)")
                print("Store URL: \(storeDescription.url?.absoluteString ?? "nil")")
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
    }
    
    // MARK: - View-Triggered Loading
    
    /// Start Core Data loading when the view is ready
    /// This ensures static samples are rendered first
    func startCoreDataLoading() {
        guard !isReady else { return } // Already loaded
        
        Task(priority: .background) {
            print("Core Data: Starting load after view rendered...")
            let inMemory = container.persistentStoreDescriptions.first?.url == URL(fileURLWithPath: "/dev/null")
            await loadStores(inMemory: inMemory)
        }
    }
    
    // MARK: - Sample Data Import
    
    /// Import sample cards if this is a fresh install
    @MainActor
    private func importSamplesIfNeeded() async {
        let context = container.viewContext
        
        // No need to wait for sync anymore
        
        // Check if we already have the sample scripts (by their fixed IDs)
        let sampleIDs = [
            StaticSampleCard.smokingSampleID,
            StaticSampleCard.bedtimeSampleID,
            StaticSampleCard.mistakesSampleID
        ]
        
        let fetchRequest = SelftalkScript.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", sampleIDs)
        let existingSamples = (try? context.fetch(fetchRequest)) ?? []
        
        if existingSamples.count >= 3 {
            print("Sample scripts already exist, skipping import")
            return
        }
        
        print("Importing missing sample scripts...")
        
        // Get static samples
        let samples = StaticSampleProvider.shared.getSamples()
        
        for sample in samples {
            // Check if this specific sample already exists (by ID or content)
            let fetchRequest = SelftalkScript.fetchRequest()
            
            // Check by ID first
            fetchRequest.predicate = NSPredicate(format: "id == %@", sample.id as CVarArg)
            fetchRequest.fetchLimit = 1
            
            var existing = try? context.fetch(fetchRequest).first
            
            // If not found by ID, check by content to avoid content duplicates
            if existing == nil {
                let normalizedText = sample.scriptText.trimmingCharacters(in: .whitespacesAndNewlines)
                fetchRequest.predicate = NSPredicate(format: "scriptText CONTAINS[c] %@", normalizedText)
                existing = try? context.fetch(fetchRequest).first
            }
            
            guard existing == nil else {
                print("Sample '\(sample.category)' already exists, skipping")
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
            
            // Mark that we've launched before (to coordinate with other first-launch checks)
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        } catch {
            print("Failed to save sample scripts: \(error)")
        }
    }
}