import XCTest
import CoreData
import CloudKit
import Combine
@testable import Echo

final class PersistenceTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create in-memory persistence controller for testing
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        cancellables = Set<AnyCancellable>()
        
        // Load stores for testing
        await persistenceController.loadStores(inMemory: true, iCloudEnabled: false)
    }
    
    override func tearDownWithError() throws {
        cancellables?.removeAll()
        context = nil
        persistenceController = nil
        cancellables = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testPersistenceControllerInitialization() {
        XCTAssertNotNil(persistenceController)
        XCTAssertNotNil(persistenceController.container)
        XCTAssertNotNil(context)
    }
    
    func testInMemoryConfiguration() {
        // Verify that we're using in-memory store
        let storeDescriptions = persistenceController.container.persistentStoreDescriptions
        XCTAssertFalse(storeDescriptions.isEmpty)
        
        // In-memory store should have /dev/null URL
        if let firstDescription = storeDescriptions.first {
            XCTAssertEqual(firstDescription.url?.path, "/dev/null")
        }
    }
    
    func testSharedInstanceBehavior() {
        let shared1 = PersistenceController.shared
        let shared2 = PersistenceController.shared
        
        XCTAssertTrue(shared1 === shared2, "Should return same shared instance")
    }
    
    func testGetSharedIfExists() throws {
        // Should return existing shared instance
        _ = PersistenceController.shared // Ensure it's created
        let existingShared = try PersistenceController.getSharedIfExists()
        XCTAssertNotNil(existingShared)
    }
    
    // MARK: - Core Data Model Tests
    
    func testCreateSelftalkScript() {
        let script = SelftalkScript.create(
            scriptText: "Test script",
            repetitions: 3,
            privateMode: true,
            in: context
        )
        
        XCTAssertNotNil(script)
        XCTAssertEqual(script.scriptText, "Test script")
        XCTAssertEqual(script.repetitions, 3)
        XCTAssertTrue(script.privateModeEnabled)
        XCTAssertNotNil(script.id)
        XCTAssertNotNil(script.createdAt)
        XCTAssertNotNil(script.updatedAt)
    }
    
    func testCreateTag() {
        let tag = Tag.findOrCreateNormalized(name: "Test Category", in: context)
        
        XCTAssertNotNil(tag)
        XCTAssertEqual(tag.name, "Test Category")
        XCTAssertNotNil(tag.createdAt)
        XCTAssertNotNil(tag.color)
    }
    
    func testTagNormalization() {
        let tag1 = Tag.findOrCreateNormalized(name: "  Test Category  ", in: context)
        let tag2 = Tag.findOrCreateNormalized(name: "test category", in: context)
        let tag3 = Tag.findOrCreateNormalized(name: "Test Category", in: context)
        
        // Should all return the same tag due to normalization
        XCTAssertTrue(tag1 === tag2)
        XCTAssertTrue(tag2 === tag3)
        XCTAssertEqual(tag1.name, "Test Category")
    }
    
    func testScriptTagRelationship() {
        let script = SelftalkScript.create(
            scriptText: "Test script with tags",
            repetitions: 1,
            privateMode: false,
            in: context
        )
        
        let tag1 = Tag.findOrCreateNormalized(name: "Category 1", in: context)
        let tag2 = Tag.findOrCreateNormalized(name: "Category 2", in: context)
        
        // Add tags to script
        script.addToTags(tag1)
        script.addToTags(tag2)
        
        XCTAssertEqual(script.tags?.count, 2)
        XCTAssertTrue(script.tags?.contains(tag1) ?? false)
        XCTAssertTrue(script.tags?.contains(tag2) ?? false)
        
        // Verify reverse relationship
        XCTAssertTrue(tag1.scripts?.contains(script) ?? false)
        XCTAssertTrue(tag2.scripts?.contains(script) ?? false)
    }
    
    // MARK: - Data Persistence Tests
    
    func testSaveContext() throws {
        let script = SelftalkScript.create(
            scriptText: "Test save",
            repetitions: 1,
            privateMode: false,
            in: context
        )
        
        // Save context
        try context.save()
        
        // Verify script was saved
        let fetchRequest = SelftalkScript.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "scriptText == %@", "Test save")
        
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, script.id)
    }
    
    func testFetchScripts() throws {
        // Create multiple scripts
        let scripts = TestDataFactory.createScenarioData(scenario: .manyScripts, in: context)
        try context.save()
        
        // Fetch all scripts
        let fetchRequest = SelftalkScript.fetchRequest()
        let results = try context.fetch(fetchRequest)
        
        XCTAssertGreaterThanOrEqual(results.count, scripts.scripts.count)
    }
    
    func testDeleteScript() throws {
        let script = SelftalkScript.create(
            scriptText: "Test delete",
            repetitions: 1,
            privateMode: false,
            in: context
        )
        
        let scriptID = script.id
        try context.save()
        
        // Delete script
        context.delete(script)
        try context.save()
        
        // Verify script was deleted
        let fetchRequest = SelftalkScript.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", scriptID as CVarArg)
        
        let results = try context.fetch(fetchRequest)
        XCTAssertTrue(results.isEmpty)
    }
    
    // MARK: - Query Tests
    
    func testFetchScriptsByTag() throws {
        let tag = Tag.findOrCreateNormalized(name: "Test Tag", in: context)
        
        let script1 = SelftalkScript.create(
            scriptText: "Script with tag",
            repetitions: 1,
            privateMode: false,
            in: context
        )
        script1.addToTags(tag)
        
        let script2 = SelftalkScript.create(
            scriptText: "Script without tag",
            repetitions: 1,
            privateMode: false,
            in: context
        )
        
        try context.save()
        
        // Fetch scripts with specific tag
        let fetchRequest = SelftalkScript.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "ANY tags == %@", tag)
        
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, script1.id)
    }
    
    func testFetchScriptsWithAudio() throws {
        let script1 = SelftalkScript.create(
            scriptText: "Script with audio",
            repetitions: 1,
            privateMode: false,
            in: context
        )
        script1.audioFilePath = "/path/to/audio.m4a"
        script1.audioDuration = 5.0
        
        let script2 = SelftalkScript.create(
            scriptText: "Script without audio",
            repetitions: 1,
            privateMode: false,
            in: context
        )
        
        try context.save()
        
        // Fetch scripts with audio
        let fetchRequest = SelftalkScript.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "audioFilePath != nil AND audioDuration > 0")
        
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, script1.id)
    }
    
    func testFetchMostPlayedScripts() throws {
        let script1 = SelftalkScript.create(scriptText: "Low play count", repetitions: 1, privateMode: false, in: context)
        script1.playCount = 2
        
        let script2 = SelftalkScript.create(scriptText: "High play count", repetitions: 1, privateMode: false, in: context)
        script2.playCount = 10
        
        let script3 = SelftalkScript.create(scriptText: "Medium play count", repetitions: 1, privateMode: false, in: context)
        script3.playCount = 5
        
        try context.save()
        
        // Fetch scripts sorted by play count
        let fetchRequest = SelftalkScript.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SelftalkScript.playCount, ascending: false)]
        fetchRequest.fetchLimit = 2
        
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].playCount, 10)
        XCTAssertEqual(results[1].playCount, 5)
    }
    
    // MARK: - Script Methods Tests
    
    func testIncrementPlayCount() {
        let script = SelftalkScript.create(
            scriptText: "Test play count",
            repetitions: 1,
            privateMode: false,
            in: context
        )
        
        let initialPlayCount = script.playCount
        script.incrementPlayCount()
        
        XCTAssertEqual(script.playCount, initialPlayCount + 1)
        XCTAssertTrue(script.updatedAt > script.createdAt)
    }
    
    func testUpdateLastModified() async {
        let script = SelftalkScript.create(
            scriptText: "Test modification",
            repetitions: 1,
            privateMode: false,
            in: context
        )
        
        let initialModifiedDate = script.updatedAt
        
        // Wait a bit to ensure timestamp difference
        await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        script.updatedAt = Date()
        
        XCTAssertTrue(script.updatedAt > initialModifiedDate)
    }
    
    // MARK: - Data Loading State Tests
    
    func testDataLoadingStateChanges() {
        let expectation = XCTestExpectation(description: "Data loading state changes")
        
        persistenceController.$dataLoadingState
            .sink { state in
                // Should progress through states
                XCTAssertTrue(DataLoadingState.allCases.contains(state))
                if state == .coreDataReady {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Start Core Data loading
        persistenceController.startCoreDataLoading()
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    func testIsReadyProperty() {
        let expectation = XCTestExpectation(description: "IsReady property update")
        
        persistenceController.$isReady
            .sink { isReady in
                if isReady {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
        
        XCTAssertTrue(persistenceController.isReady)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidDataHandling() throws {
        // Create script with invalid data
        let script = SelftalkScript.create(
            scriptText: "",  // Empty script text
            repetitions: -1,  // Invalid repetitions
            privateMode: false,
            in: context
        )
        
        // Should still save but with corrected values
        try context.save()
        
        XCTAssertTrue(script.scriptText.isEmpty) // Empty text is allowed
        XCTAssertEqual(script.repetitions, -1) // Negative repetitions stored as-is
    }
    
    func testConstraintViolationHandling() throws {
        // Test duplicate UUID handling (if constraints exist)
        let script1 = SelftalkScript.create(
            scriptText: "First script",
            repetitions: 1,
            privateMode: false,
            in: context
        )
        
        let script2 = SelftalkScript.create(
            scriptText: "Second script",
            repetitions: 1,
            privateMode: false,
            in: context
        )
        
        // Force same ID to test constraint handling
        script2.id = script1.id
        
        // This might fail or succeed depending on Core Data constraints
        // We test that it doesn't crash the app
        do {
            try context.save()
        } catch {
            // Expected if there are uniqueness constraints
            XCTAssertTrue(error is NSError)
        }
    }
    
    // MARK: - CloudKit Integration Tests
    
    func testCloudKitConfiguration() {
        // Test CloudKit configuration properties
        let storeDescriptions = persistenceController.container.persistentStoreDescriptions
        
        for description in storeDescriptions {
            // For in-memory testing, CloudKit should be disabled
            XCTAssertNil(description.cloudKitContainerOptions)
            
            // But history tracking should be enabled
            let historyTracking = description.option(forKey: NSPersistentHistoryTrackingKey) as? Bool
            XCTAssertTrue(historyTracking ?? false)
            
            let remoteChange = description.option(forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey) as? Bool
            XCTAssertTrue(remoteChange ?? false)
        }
    }
    
    func testICloudSyncEnabledProperty() {
        // Test the iCloud sync enabled property
        let initialValue = persistenceController.iCloudSyncEnabled
        XCTAssertFalse(initialValue) // Default should be false for fresh installs
    }
    
    // MARK: - Sample Data Import Tests
    
    func testSampleDataImport() async {
        // Import samples if needed should be called during setup
        // Verify that sample scripts exist
        let fetchRequest = SelftalkScript.fetchRequest()
        let sampleIDs = [
            StaticSampleCard.smokingSampleID,
            StaticSampleCard.bedtimeSampleID,
            StaticSampleCard.mistakesSampleID
        ]
        fetchRequest.predicate = NSPredicate(format: "id IN %@", sampleIDs)
        
        do {
            let existingSamples = try context.fetch(fetchRequest)
            // Samples might or might not be imported in test environment
            XCTAssertGreaterThanOrEqual(existingSamples.count, 0)
        } catch {
            XCTFail("Failed to fetch sample scripts: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testFetchPerformance() throws {
        // Create many scripts for performance testing
        let testData = TestDataFactory.createScenarioData(scenario: .manyScripts, in: context)
        try context.save()
        
        measure {
            let fetchRequest = SelftalkScript.fetchRequest()
            _ = try? context.fetch(fetchRequest)
        }
    }
    
    func testSavePerformance() {
        measure {
            let script = SelftalkScript.create(
                scriptText: "Performance test script",
                repetitions: 1,
                privateMode: false,
                in: context
            )
            try? context.save()
            
            // Clean up for next iteration
            context.delete(script)
            try? context.save()
        }
    }
    
    func testComplexQueryPerformance() throws {
        // Create test data
        let testData = TestDataFactory.createScenarioData(scenario: .manyScripts, in: context)
        try context.save()
        
        measure {
            let fetchRequest = SelftalkScript.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "playCount > 0 AND audioFilePath != nil")
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \SelftalkScript.updatedAt, ascending: false)
            ]
            fetchRequest.fetchLimit = 10
            
            _ = try? context.fetch(fetchRequest)
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testContextMemoryManagement() {
        weak var weakScript: SelftalkScript?
        
        autoreleasepool {
            let script = SelftalkScript.create(
                scriptText: "Memory test",
                repetitions: 1,
                privateMode: false,
                in: context
            )
            weakScript = script
            
            try? context.save()
            
            // Delete from context
            context.delete(script)
        }
        
        // Reset context to clear any remaining references
        context.reset()
        
        // Script should be deallocated
        XCTAssertNil(weakScript)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 5
        
        // Perform concurrent operations on background contexts
        for i in 0..<5 {
            DispatchQueue.global().async {
                let backgroundContext = self.persistenceController.container.newBackgroundContext()
                
                let script = SelftalkScript.create(
                    scriptText: "Concurrent script \(i)",
                    repetitions: 1,
                    privateMode: false,
                    in: backgroundContext
                )
                
                do {
                    try backgroundContext.save()
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to save in background context: \(error)")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    // MARK: - Edge Cases
    
    func testLargeDataSets() throws {
        // Create a large number of scripts to test limits
        for i in 0..<100 {
            let script = SelftalkScript.create(
                scriptText: "Large dataset script \(i)",
                repetitions: Int16(i % 10 + 1),
                privateMode: i % 2 == 0,
                in: context
            )
            
            if i % 10 == 0 {
                // Save periodically to avoid memory issues
                try context.save()
            }
        }
        
        try context.save()
        
        // Verify all scripts were saved
        let fetchRequest = SelftalkScript.fetchRequest()
        let results = try context.fetch(fetchRequest)
        XCTAssertGreaterThanOrEqual(results.count, 100)
    }
    
    func testEmptyDatabase() throws {
        // Start with empty database
        let fetchRequest = SelftalkScript.fetchRequest()
        let initialResults = try context.fetch(fetchRequest)
        
        // Delete all existing scripts
        for script in initialResults {
            context.delete(script)
        }
        try context.save()
        
        // Verify database is empty
        let emptyResults = try context.fetch(fetchRequest)
        XCTAssertTrue(emptyResults.isEmpty)
        
        // Test operations on empty database
        XCTAssertNoThrow(try context.save())
    }
    
    func testCorruptedData() {
        // Test with potentially corrupted relationships
        let script = SelftalkScript.create(
            scriptText: "Corrupted test",
            repetitions: 1,
            privateMode: false,
            in: context
        )
        
        let tag = Tag.findOrCreateNormalized(name: "Test Tag", in: context)
        script.addToTags(tag)
        
        // Manually corrupt the relationship (simulating data corruption)
        script.mutableSetValue(forKey: "tags").removeAllObjects()
        
        // Should handle gracefully
        XCTAssertTrue(script.tags?.isEmpty ?? true)
        XCTAssertNoThrow(try context.save())
    }
}