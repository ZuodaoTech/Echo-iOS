import XCTest
@testable import Echo

final class StaticSampleCardTests: XCTestCase {
    
    var staticSampleProvider: StaticSampleProvider!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        staticSampleProvider = StaticSampleProvider.shared
        
        // Clear cache to start fresh
        staticSampleProvider.clearCache()
    }
    
    override func tearDownWithError() throws {
        staticSampleProvider.clearCache()
        staticSampleProvider = nil
        try super.tearDownWithError()
    }
    
    // MARK: - UUID Constants Tests
    
    func testStaticSampleUUIDs() {
        // Test that all sample UUIDs are valid and unique
        let smokingID = StaticSampleCard.smokingSampleID
        let bedtimeID = StaticSampleCard.bedtimeSampleID
        let mistakesID = StaticSampleCard.mistakesSampleID
        
        XCTAssertNotNil(smokingID)
        XCTAssertNotNil(bedtimeID)
        XCTAssertNotNil(mistakesID)
        
        // UUIDs should be unique
        XCTAssertNotEqual(smokingID, bedtimeID)
        XCTAssertNotEqual(bedtimeID, mistakesID)
        XCTAssertNotEqual(smokingID, mistakesID)
    }
    
    func testStaticSampleUUIDConsistency() {
        // UUIDs should be consistent across multiple calls
        let smokingID1 = StaticSampleCard.smokingSampleID
        let smokingID2 = StaticSampleCard.smokingSampleID
        XCTAssertEqual(smokingID1, smokingID2)
        
        let bedtimeID1 = StaticSampleCard.bedtimeSampleID
        let bedtimeID2 = StaticSampleCard.bedtimeSampleID
        XCTAssertEqual(bedtimeID1, bedtimeID2)
        
        let mistakesID1 = StaticSampleCard.mistakesSampleID
        let mistakesID2 = StaticSampleCard.mistakesSampleID
        XCTAssertEqual(mistakesID1, mistakesID2)
    }
    
    func testExpectedUUIDValues() {
        // Test that UUIDs match expected values for deduplication
        XCTAssertEqual(StaticSampleCard.smokingSampleID.uuidString, "00000000-0000-0000-0000-000000000001")
        XCTAssertEqual(StaticSampleCard.bedtimeSampleID.uuidString, "00000000-0000-0000-0000-000000000002")
        XCTAssertEqual(StaticSampleCard.mistakesSampleID.uuidString, "00000000-0000-0000-0000-000000000003")
    }
    
    // MARK: - StaticSampleCard Structure Tests
    
    func testStaticSampleCardCreation() {
        let card = StaticSampleCard(
            id: UUID(),
            scriptText: "Test script",
            category: "Test Category",
            repetitions: 3,
            intervalSeconds: 2.0
        )
        
        XCTAssertNotNil(card.id)
        XCTAssertEqual(card.scriptText, "Test script")
        XCTAssertEqual(card.category, "Test Category")
        XCTAssertEqual(card.repetitions, 3)
        XCTAssertEqual(card.intervalSeconds, 2.0)
    }
    
    func testStaticSampleCardIdentifiable() {
        let card1 = StaticSampleCard(
            id: StaticSampleCard.smokingSampleID,
            scriptText: "Test 1",
            category: "Category 1",
            repetitions: 1,
            intervalSeconds: 1.0
        )
        
        let card2 = StaticSampleCard(
            id: StaticSampleCard.bedtimeSampleID,
            scriptText: "Test 2",
            category: "Category 2",
            repetitions: 2,
            intervalSeconds: 2.0
        )
        
        // Should conform to Identifiable
        XCTAssertNotEqual(card1.id, card2.id)
    }
    
    // MARK: - StaticSampleProvider Tests
    
    func testSingletonBehavior() {
        let provider1 = StaticSampleProvider.shared
        let provider2 = StaticSampleProvider.shared
        
        XCTAssertTrue(provider1 === provider2, "StaticSampleProvider should be a singleton")
    }
    
    func testGetSamplesBasicStructure() {
        let samples = staticSampleProvider.getSamples()
        
        XCTAssertEqual(samples.count, 3, "Should have exactly 3 sample cards")
        
        // Verify all samples have required properties
        for sample in samples {
            XCTAssertFalse(sample.scriptText.isEmpty)
            XCTAssertFalse(sample.category.isEmpty)
            XCTAssertGreaterThan(sample.repetitions, 0)
            XCTAssertGreaterThan(sample.intervalSeconds, 0)
        }
    }
    
    func testGetSamplesUsesPredefinedIDs() {
        let samples = staticSampleProvider.getSamples()
        
        let sampleIDs = samples.map { $0.id }
        
        XCTAssertTrue(sampleIDs.contains(StaticSampleCard.smokingSampleID))
        XCTAssertTrue(sampleIDs.contains(StaticSampleCard.bedtimeSampleID))
        XCTAssertTrue(sampleIDs.contains(StaticSampleCard.mistakesSampleID))
    }
    
    func testGetSamplesContent() {
        let samples = staticSampleProvider.getSamples()
        
        // Find each sample by ID and verify content
        let smokingSample = samples.first { $0.id == StaticSampleCard.smokingSampleID }
        XCTAssertNotNil(smokingSample)
        XCTAssertFalse(smokingSample!.scriptText.isEmpty)
        
        let bedtimeSample = samples.first { $0.id == StaticSampleCard.bedtimeSampleID }
        XCTAssertNotNil(bedtimeSample)
        XCTAssertFalse(bedtimeSample!.scriptText.isEmpty)
        
        let mistakesSample = samples.first { $0.id == StaticSampleCard.mistakesSampleID }
        XCTAssertNotNil(mistakesSample)
        XCTAssertFalse(mistakesSample!.scriptText.isEmpty)
    }
    
    func testGetSamplesUsesLocalization() {
        let samples = staticSampleProvider.getSamples()
        
        // Verify that samples use localized strings
        // (The actual content depends on the current locale)
        for sample in samples {
            // Script text should not be the localization key
            XCTAssertFalse(sample.scriptText.hasPrefix("sample."))
            XCTAssertFalse(sample.category.hasPrefix("tag."))
        }
    }
    
    // MARK: - Caching Tests
    
    func testSampleCaching() {
        // First call should create samples
        let samples1 = staticSampleProvider.getSamples()
        
        // Second call should return cached samples
        let samples2 = staticSampleProvider.getSamples()
        
        XCTAssertEqual(samples1.count, samples2.count)
        
        // Verify IDs are the same (indicating same objects or consistent creation)
        for i in 0..<samples1.count {
            XCTAssertEqual(samples1[i].id, samples2[i].id)
            XCTAssertEqual(samples1[i].scriptText, samples2[i].scriptText)
        }
    }
    
    func testClearCache() {
        // Get samples to populate cache
        let initialSamples = staticSampleProvider.getSamples()
        XCTAssertFalse(initialSamples.isEmpty)
        
        // Clear cache
        staticSampleProvider.clearCache()
        
        // Get samples again (should recreate)
        let newSamples = staticSampleProvider.getSamples()
        
        // Should have same structure
        XCTAssertEqual(newSamples.count, initialSamples.count)
        
        // Verify consistency after cache clear
        for i in 0..<initialSamples.count {
            XCTAssertEqual(newSamples[i].id, initialSamples[i].id)
        }
    }
    
    // MARK: - Sample ID Detection Tests
    
    func testIsSampleID() {
        // Should identify sample IDs correctly
        XCTAssertTrue(StaticSampleProvider.isSampleID(StaticSampleCard.smokingSampleID))
        XCTAssertTrue(StaticSampleProvider.isSampleID(StaticSampleCard.bedtimeSampleID))
        XCTAssertTrue(StaticSampleProvider.isSampleID(StaticSampleCard.mistakesSampleID))
        
        // Should not identify random UUIDs as sample IDs
        XCTAssertFalse(StaticSampleProvider.isSampleID(UUID()))
        XCTAssertFalse(StaticSampleProvider.isSampleID(UUID()))
    }
    
    func testIsSampleIDWithSpecificValues() {
        // Test with manually created UUIDs that match the expected values
        let smokingUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let bedtimeUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let mistakesUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        
        XCTAssertTrue(StaticSampleProvider.isSampleID(smokingUUID))
        XCTAssertTrue(StaticSampleProvider.isSampleID(bedtimeUUID))
        XCTAssertTrue(StaticSampleProvider.isSampleID(mistakesUUID))
        
        // Test with similar but different UUIDs
        let notSampleUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        XCTAssertFalse(StaticSampleProvider.isSampleID(notSampleUUID))
    }
    
    // MARK: - Performance Tests
    
    func testGetSamplesPerformance() {
        measure {
            _ = staticSampleProvider.getSamples()
        }
    }
    
    func testCachedSamplesPerformance() {
        // Prime the cache
        _ = staticSampleProvider.getSamples()
        
        // Measure cached access
        measure {
            for _ in 0..<100 {
                _ = staticSampleProvider.getSamples()
            }
        }
    }
    
    func testIsSampleIDPerformance() {
        let testUUIDs = [
            StaticSampleCard.smokingSampleID,
            StaticSampleCard.bedtimeSampleID,
            StaticSampleCard.mistakesSampleID,
            UUID(),
            UUID(),
            UUID()
        ]
        
        measure {
            for _ in 0..<1000 {
                for uuid in testUUIDs {
                    _ = StaticSampleProvider.isSampleID(uuid)
                }
            }
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent access to samples")
        expectation.expectedFulfillmentCount = 5
        
        // Access samples from multiple threads
        for _ in 0..<5 {
            DispatchQueue.global().async {
                let samples = self.staticSampleProvider.getSamples()
                XCTAssertEqual(samples.count, 3)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    func testConcurrentCacheOperations() {
        let expectation = XCTestExpectation(description: "Concurrent cache operations")
        expectation.expectedFulfillmentCount = 10
        
        // Mix cache clears and sample requests
        for i in 0..<10 {
            DispatchQueue.global().async {
                if i % 2 == 0 {
                    self.staticSampleProvider.clearCache()
                } else {
                    _ = self.staticSampleProvider.getSamples()
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    // MARK: - Integration Tests
    
    func testSamplesAreValidForCoreData() {
        let samples = staticSampleProvider.getSamples()
        
        // Verify that all properties would be valid for Core Data entities
        for sample in samples {
            // Text should not be empty (required field)
            XCTAssertFalse(sample.scriptText.trimmingCharacters(in: .whitespaces).isEmpty)
            
            // Repetitions should be positive
            XCTAssertGreaterThan(sample.repetitions, 0)
            XCTAssertLessThanOrEqual(sample.repetitions, 100) // Reasonable upper bound
            
            // Interval should be reasonable
            XCTAssertGreaterThan(sample.intervalSeconds, 0)
            XCTAssertLessThanOrEqual(sample.intervalSeconds, 300) // 5 minutes max
            
            // Category should not be empty
            XCTAssertFalse(sample.category.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
    
    func testSampleIDsMatchConstants() {
        let samples = staticSampleProvider.getSamples()
        
        // Find each sample and verify its ID matches the constant
        for sample in samples {
            switch sample.id {
            case StaticSampleCard.smokingSampleID:
                // Found smoking sample
                XCTAssertTrue(sample.scriptText.count > 0)
            case StaticSampleCard.bedtimeSampleID:
                // Found bedtime sample
                XCTAssertTrue(sample.scriptText.count > 0)
            case StaticSampleCard.mistakesSampleID:
                // Found mistakes sample
                XCTAssertTrue(sample.scriptText.count > 0)
            default:
                XCTFail("Unexpected sample ID: \(sample.id)")
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testEmptyCacheHandling() {
        // Ensure cache starts empty
        staticSampleProvider.clearCache()
        
        // Getting samples should work even with empty cache
        let samples = staticSampleProvider.getSamples()
        XCTAssertEqual(samples.count, 3)
    }
    
    func testMultipleCacheClearsAndGets() {
        // Rapid cache operations shouldn't cause issues
        for _ in 0..<10 {
            staticSampleProvider.clearCache()
            let samples = staticSampleProvider.getSamples()
            XCTAssertEqual(samples.count, 3)
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryUsage() {
        // Get samples multiple times and clear cache
        for _ in 0..<100 {
            _ = staticSampleProvider.getSamples()
            if arc4random() % 10 == 0 {  // Clear cache occasionally
                staticSampleProvider.clearCache()
            }
        }
        
        // Should not cause memory issues
        XCTAssertTrue(true)
    }
    
    // MARK: - Localization Edge Cases
    
    func testHandlesMissingLocalizations() {
        // Even if localizations are missing, should not crash
        let samples = staticSampleProvider.getSamples()
        
        // Should still return 3 samples
        XCTAssertEqual(samples.count, 3)
        
        // Each sample should have some content (even if it's the key)
        for sample in samples {
            XCTAssertFalse(sample.scriptText.isEmpty)
            XCTAssertFalse(sample.category.isEmpty)
        }
    }
}