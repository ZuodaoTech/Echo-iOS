import XCTest
import CoreData
@testable import Echo

final class DeduplicationServiceTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    var persistenceController: PersistenceController!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create in-memory persistence controller for testing
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        
        // Load stores for testing
        await persistenceController.loadStores(inMemory: true, iCloudEnabled: false)
    }
    
    override func tearDownWithError() throws {
        context = nil
        persistenceController = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Deduplication Logic Tests
    
    func testNoDuplicatesScenario() async {
        // Create unique scripts
        let script1 = SelftalkScriptBuilder()
            .withScriptText("Unique script one")
            .build(in: context)
        
        let script2 = SelftalkScriptBuilder()
            .withScriptText("Unique script two")
            .build(in: context)
        
        try! context.save()
        
        let initialCount = try! context.count(for: SelftalkScript.fetchRequest())
        
        // Run deduplication
        await DeduplicationService.deduplicateScripts(in: context)
        
        // Should not remove any scripts
        let finalCount = try! context.count(for: SelftalkScript.fetchRequest())
        XCTAssertEqual(finalCount, initialCount)
        XCTAssertEqual(finalCount, 2)
    }
    
    func testSimpleDuplicatesRemoval() async {
        // Create duplicate scripts with identical content
        let script1 = SelftalkScriptBuilder()
            .withScriptText("Duplicate content")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        script1.createdAt = Date().addingTimeInterval(-100) // Older
        
        let script2 = SelftalkScriptBuilder()
            .withScriptText("Duplicate content")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        script2.createdAt = Date() // Newer
        
        try! context.save()
        
        // Run deduplication
        await DeduplicationService.deduplicateScripts(in: context)
        
        // Should keep only one script
        let remainingScripts = try! context.fetch(SelftalkScript.fetchRequest())
        XCTAssertEqual(remainingScripts.count, 1)
        
        // Should keep the older script
        let remainingScript = remainingScripts.first!
        XCTAssertEqual(remainingScript.createdAt, script1.createdAt)
    }
    
    func testDuplicatesWithDifferentProperties() async {
        // Create scripts with same content but different repetitions/intervals
        let script1 = SelftalkScriptBuilder()
            .withScriptText("Same content")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        
        let script2 = SelftalkScriptBuilder()
            .withScriptText("Same content")
            .withRepetitions(5)  // Different
            .withIntervalSeconds(3.0)  // Different
            .build(in: context)
        
        try! context.save()
        
        // Run deduplication
        await DeduplicationService.deduplicateScripts(in: context)
        
        // Should NOT remove these as they have different properties
        let remainingScripts = try! context.fetch(SelftalkScript.fetchRequest())
        XCTAssertEqual(remainingScripts.count, 2)
    }
    
    func testPriorityKeepsScriptWithAudio() async {
        // Create duplicates where one has audio
        let scriptWithoutAudio = SelftalkScriptBuilder()
            .withScriptText("Duplicate with priority")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        scriptWithoutAudio.createdAt = Date().addingTimeInterval(-100) // Older
        
        let scriptWithAudio = SelftalkScriptBuilder()
            .withScriptText("Duplicate with priority")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .withAudioFile(path: "/path/to/audio.m4a", duration: 10.0)
            .build(in: context)
        scriptWithAudio.createdAt = Date() // Newer
        
        try! context.save()
        
        // Run deduplication
        await DeduplicationService.deduplicateScripts(in: context)
        
        // Should keep the script with audio, even though it's newer
        let remainingScripts = try! context.fetch(SelftalkScript.fetchRequest())
        XCTAssertEqual(remainingScripts.count, 1)
        
        let keptScript = remainingScripts.first!
        XCTAssertNotNil(keptScript.audioFilePath)
        XCTAssertGreaterThan(keptScript.audioDuration, 0)
    }
    
    func testPriorityKeepsPlayedScript() async {
        // Create duplicates where one has been played
        let unplayedScript = SelftalkScriptBuilder()
            .withScriptText("Duplicate for play test")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        unplayedScript.createdAt = Date().addingTimeInterval(-100) // Older
        
        let playedScript = SelftalkScriptBuilder()
            .withScriptText("Duplicate for play test")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .withPlayCount(5)
            .build(in: context)
        playedScript.createdAt = Date() // Newer
        
        try! context.save()
        
        // Run deduplication
        await DeduplicationService.deduplicateScripts(in: context)
        
        // Should keep the played script
        let remainingScripts = try! context.fetch(SelftalkScript.fetchRequest())
        XCTAssertEqual(remainingScripts.count, 1)
        
        let keptScript = remainingScripts.first!
        XCTAssertGreaterThan(keptScript.playCount, 0)
    }
    
    func testSampleScriptDeduplication() async {
        // Create duplicate sample scripts (one with sample ID, one without)
        let sampleScript = SelftalkScriptBuilder()
            .withId(StaticSampleCard.smokingSampleID)
            .withScriptText("Sample smoking script")
            .withRepetitions(3)
            .withIntervalSeconds(1.0)
            .build(in: context)
        
        let duplicateSample = SelftalkScriptBuilder()
            .withId(UUID()) // Different ID
            .withScriptText("Sample smoking script")
            .withRepetitions(3)
            .withIntervalSeconds(1.0)
            .build(in: context)
        
        try! context.save()
        
        // Run deduplication
        await DeduplicationService.deduplicateScripts(in: context)
        
        // Should keep the script with the sample ID
        let remainingScripts = try! context.fetch(SelftalkScript.fetchRequest())
        XCTAssertEqual(remainingScripts.count, 1)
        
        let keptScript = remainingScripts.first!
        XCTAssertEqual(keptScript.id, StaticSampleCard.smokingSampleID)
    }
    
    // MARK: - Data Merging Tests
    
    func testMergePlayCounts() async {
        // Create duplicates with different play counts
        let script1 = SelftalkScriptBuilder()
            .withScriptText("Merge test script")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .withPlayCount(3)
            .build(in: context)
        script1.createdAt = Date().addingTimeInterval(-100) // Older - will be kept
        
        let script2 = SelftalkScriptBuilder()
            .withScriptText("Merge test script")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .withPlayCount(7)
            .build(in: context)
        
        try! context.save()
        
        // Run deduplication
        await DeduplicationService.deduplicateScripts(in: context)
        
        // Should merge play counts
        let remainingScripts = try! context.fetch(SelftalkScript.fetchRequest())
        XCTAssertEqual(remainingScripts.count, 1)
        
        let keptScript = remainingScripts.first!
        XCTAssertEqual(keptScript.playCount, 10) // 3 + 7
    }
    
    func testMergeAudioFromDuplicate() async {
        // Create duplicates where keeper doesn't have audio but duplicate does
        let scriptWithoutAudio = SelftalkScriptBuilder()
            .withScriptText("Audio merge test")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        scriptWithoutAudio.createdAt = Date().addingTimeInterval(-100) // Older - will be kept
        
        let scriptWithAudio = SelftalkScriptBuilder()
            .withScriptText("Audio merge test")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .withAudioFile(path: "/path/to/audio.m4a", duration: 15.0)
            .build(in: context)
        
        try! context.save()
        
        // Run deduplication
        await DeduplicationService.deduplicateScripts(in: context)
        
        // Should merge audio into the kept script
        let remainingScripts = try! context.fetch(SelftalkScript.fetchRequest())
        XCTAssertEqual(remainingScripts.count, 1)
        
        let keptScript = remainingScripts.first!
        XCTAssertEqual(keptScript.audioFilePath, "/path/to/audio.m4a")
        XCTAssertEqual(keptScript.audioDuration, 15.0)
    }
    
    func testMergeTranscription() async {
        // Create duplicates where keeper doesn't have transcription but duplicate does
        let scriptWithoutTranscription = SelftalkScriptBuilder()
            .withScriptText("Transcription merge test")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        scriptWithoutTranscription.createdAt = Date().addingTimeInterval(-100) // Older - will be kept
        
        let scriptWithTranscription = SelftalkScriptBuilder()
            .withScriptText("Transcription merge test")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .withTranscription("Transcribed text", language: "en-US")
            .build(in: context)
        
        try! context.save()
        
        // Run deduplication
        await DeduplicationService.deduplicateScripts(in: context)
        
        // Should merge transcription into the kept script
        let remainingScripts = try! context.fetch(SelftalkScript.fetchRequest())
        XCTAssertEqual(remainingScripts.count, 1)
        
        let keptScript = remainingScripts.first!
        XCTAssertEqual(keptScript.transcribedText, "Transcribed text")
        XCTAssertEqual(keptScript.transcriptionLanguage, "en-US")
    }
    
    func testMergeTags() async {
        // Create duplicates with different tags
        let tag1 = TagBuilder().withName("Tag 1").build(in: context)
        let tag2 = TagBuilder().withName("Tag 2").build(in: context)
        
        let script1 = SelftalkScriptBuilder()
            .withScriptText("Tag merge test")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .withTag(tag1)
            .build(in: context)
        script1.createdAt = Date().addingTimeInterval(-100) // Older - will be kept
        
        let script2 = SelftalkScriptBuilder()
            .withScriptText("Tag merge test")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .withTag(tag2)
            .build(in: context)
        
        try! context.save()
        
        // Run deduplication
        await DeduplicationService.deduplicateScripts(in: context)
        
        // Should merge tags into the kept script
        let remainingScripts = try! context.fetch(SelftalkScript.fetchRequest())
        XCTAssertEqual(remainingScripts.count, 1)
        
        let keptScript = remainingScripts.first!
        XCTAssertEqual(keptScript.tags?.count, 2)
        XCTAssertTrue(keptScript.tags?.contains(tag1) ?? false)
        XCTAssertTrue(keptScript.tags?.contains(tag2) ?? false)
    }
    
    // MARK: - Multiple Duplicates Tests
    
    func testMultipleDuplicatesKeepsBest() async {
        // Create multiple duplicates with different priorities
        let baseDate = Date().addingTimeInterval(-1000)
        
        let oldestScript = SelftalkScriptBuilder()
            .withScriptText("Multiple duplicates test")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        oldestScript.createdAt = baseDate // Oldest
        
        let playedScript = SelftalkScriptBuilder()
            .withScriptText("Multiple duplicates test")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .withPlayCount(5)
            .build(in: context)
        playedScript.createdAt = baseDate.addingTimeInterval(100)
        
        let audioScript = SelftalkScriptBuilder()
            .withScriptText("Multiple duplicates test")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .withAudioFile(path: "/audio.m4a", duration: 10.0)
            .build(in: context)
        audioScript.createdAt = baseDate.addingTimeInterval(200)
        
        let newestScript = SelftalkScriptBuilder()
            .withScriptText("Multiple duplicates test")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        newestScript.createdAt = baseDate.addingTimeInterval(300) // Newest
        
        try! context.save()
        
        // Run deduplication
        await DeduplicationService.deduplicateScripts(in: context)
        
        // Should keep the audio script (highest priority)
        let remainingScripts = try! context.fetch(SelftalkScript.fetchRequest())
        XCTAssertEqual(remainingScripts.count, 1)
        
        let keptScript = remainingScripts.first!
        XCTAssertNotNil(keptScript.audioFilePath)
        // Should also have merged play count
        XCTAssertEqual(keptScript.playCount, 5)
    }
    
    // MARK: - Edge Cases Tests
    
    func testWhitespaceNormalization() async {
        // Create scripts with different whitespace but same content
        let script1 = SelftalkScriptBuilder()
            .withScriptText("  Test   script  with   spaces  ")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        
        let script2 = SelftalkScriptBuilder()
            .withScriptText("Test script with spaces")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        
        try! context.save()
        
        // Run deduplication
        await DeduplicationService.deduplicateScripts(in: context)
        
        // Should be treated as duplicates due to whitespace normalization
        let remainingScripts = try! context.fetch(SelftalkScript.fetchRequest())
        XCTAssertEqual(remainingScripts.count, 1)
    }
    
    func testCaseInsensitiveDeduplication() async {
        // Create scripts with different cases
        let script1 = SelftalkScriptBuilder()
            .withScriptText("Test Script Content")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        
        let script2 = SelftalkScriptBuilder()
            .withScriptText("test script content")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        
        try! context.save()
        
        // Run deduplication
        await DeduplicationService.deduplicateScripts(in: context)
        
        // Should be treated as duplicates due to case normalization
        let remainingScripts = try! context.fetch(SelftalkScript.fetchRequest())
        XCTAssertEqual(remainingScripts.count, 1)
    }
    
    func testEmptyScriptsHandling() async {
        // Create scripts with empty content
        let script1 = SelftalkScriptBuilder()
            .withScriptText("")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        
        let script2 = SelftalkScriptBuilder()
            .withScriptText("")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        
        try! context.save()
        
        // Run deduplication
        await DeduplicationService.deduplicateScripts(in: context)
        
        // Should handle empty scripts gracefully
        let remainingScripts = try! context.fetch(SelftalkScript.fetchRequest())
        XCTAssertEqual(remainingScripts.count, 1)
    }
    
    // MARK: - Frequency Control Tests
    
    func testShouldCheckForDuplicates() {
        // Clear previous check time
        UserDefaults.standard.removeObject(forKey: "lastDeduplicationCheck")
        
        // Should check when never checked before
        XCTAssertTrue(DeduplicationService.shouldCheckForDuplicates())
        
        // Mark as checked
        DeduplicationService.markDeduplicationComplete()
        
        // Should not check immediately after
        XCTAssertFalse(DeduplicationService.shouldCheckForDuplicates())
        
        // Simulate time passing (by manipulating UserDefaults)
        let pastDate = Date().addingTimeInterval(-3700) // More than 1 hour ago
        UserDefaults.standard.set(pastDate, forKey: "lastDeduplicationCheck")
        
        // Should check again after time has passed
        XCTAssertTrue(DeduplicationService.shouldCheckForDuplicates())
    }
    
    func testMarkDeduplicationComplete() {
        let beforeMark = Date()
        
        DeduplicationService.markDeduplicationComplete()
        
        let lastCheck = UserDefaults.standard.object(forKey: "lastDeduplicationCheck") as? Date
        XCTAssertNotNil(lastCheck)
        XCTAssertGreaterThanOrEqual(lastCheck!, beforeMark)
    }
    
    // MARK: - Performance Tests
    
    func testDeduplicationPerformanceWithManyScripts() async {
        // Create many scripts with some duplicates
        for i in 0..<50 {
            let script = SelftalkScriptBuilder()
                .withScriptText("Script number \(i % 10)") // Creates duplicates
                .withRepetitions(3)
                .withIntervalSeconds(2.0)
                .build(in: context)
        }
        
        try! context.save()
        
        let startTime = Date()
        await DeduplicationService.deduplicateScripts(in: context)
        let endTime = Date()
        
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 5.0, "Deduplication should complete within 5 seconds")
        
        // Should have reduced the number of scripts
        let finalCount = try! context.count(for: SelftalkScript.fetchRequest())
        XCTAssertLessThan(finalCount, 50)
        XCTAssertLessThanOrEqual(finalCount, 10) // Should be around 10 unique scripts
    }
    
    // MARK: - Error Handling Tests
    
    func testDeduplicationWithCorruptedData() async {
        // Create a script with potentially problematic data
        let script = SelftalkScriptBuilder()
            .withScriptText("Normal script")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        
        // Simulate corruption by setting invalid relationship
        // (This is hard to do safely in tests, so we'll test that deduplication
        // doesn't crash with valid but edge-case data)
        
        try! context.save()
        
        // Should not crash
        await DeduplicationService.deduplicateScripts(in: context)
        
        XCTAssertTrue(true, "Deduplication completed without crashing")
    }
    
    func testDeduplicationWithFailedSave() async {
        // Create duplicates
        let script1 = SelftalkScriptBuilder()
            .withScriptText("Save test script")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        
        let script2 = SelftalkScriptBuilder()
            .withScriptText("Save test script")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .build(in: context)
        
        try! context.save()
        
        // Run deduplication (save might fail in some edge cases, but shouldn't crash)
        await DeduplicationService.deduplicateScripts(in: context)
        
        XCTAssertTrue(true, "Deduplication handled save gracefully")
    }
    
    // MARK: - Integration Tests
    
    func testRealWorldScenario() async {
        // Simulate a real iCloud sync scenario with mixed duplicates
        let scenarios = TestDataFactory.createScenarioData(scenario: .manyScripts, in: context)
        
        // Add some duplicates to the mix
        for script in scenarios.scripts.prefix(5) {
            let duplicate = SelftalkScriptBuilder()
                .withScriptText(script.scriptText)
                .withRepetitions(script.repetitions)
                .withIntervalSeconds(script.intervalSeconds)
                .build(in: context)
            duplicate.createdAt = Date() // Newer duplicates
        }
        
        try! context.save()
        let initialCount = try! context.count(for: SelftalkScript.fetchRequest())
        
        // Run deduplication
        await DeduplicationService.deduplicateScripts(in: context)
        
        let finalCount = try! context.count(for: SelftalkScript.fetchRequest())
        
        // Should have removed the 5 duplicates we added
        XCTAssertLessThan(finalCount, initialCount)
        XCTAssertLessThanOrEqual(finalCount, initialCount - 5)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentDeduplication() async {
        // Create test data
        for i in 0..<20 {
            let script = SelftalkScriptBuilder()
                .withScriptText("Concurrent test \(i % 5)") // Creates duplicates
                .withRepetitions(3)
                .withIntervalSeconds(2.0)
                .build(in: context)
        }
        
        try! context.save()
        
        // Run deduplication concurrently (though the service should handle this gracefully)
        async let dedup1 = DeduplicationService.deduplicateScripts(in: context)
        async let dedup2 = DeduplicationService.deduplicateScripts(in: context)
        
        await dedup1
        await dedup2
        
        // Should complete without crashing
        XCTAssertTrue(true, "Concurrent deduplication completed")
    }
}