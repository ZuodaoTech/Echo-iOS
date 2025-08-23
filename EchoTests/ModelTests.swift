import XCTest
import CoreData
@testable import Echo

final class ModelTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        context = PersistenceController.preview.container.viewContext
    }
    
    override func tearDown() {
        context = nil
        super.tearDown()
    }
    
    // MARK: - SelftalkScript Tests
    
    func testScriptCreation() {
        // When
        let script = SelftalkScript.create(
            scriptText: "Test script",
            category: nil,
            repetitions: 5,
            privacyMode: true,
            in: context
        )
        
        // Then
        XCTAssertNotNil(script)
        XCTAssertEqual(script.scriptText, "Test script")
        XCTAssertEqual(script.repetitions, 5)
        XCTAssertTrue(script.privacyModeEnabled)
        XCTAssertNotNil(script.id)
        XCTAssertNotNil(script.createdAt)
        XCTAssertNotNil(script.updatedAt)
    }
    
    func testScriptHasRecordingProperty() {
        // Given
        let script = SelftalkScript.create(
            scriptText: "Test",
            category: nil,
            repetitions: 1,
            privacyMode: false,
            in: context
        )
        
        // When - No recording
        XCTAssertFalse(script.hasRecording)
        
        // When - Add audio file path
        script.audioFilePath = "/path/to/audio.m4a"
        XCTAssertTrue(script.hasRecording)
        
        // When - Remove path
        script.audioFilePath = nil
        XCTAssertFalse(script.hasRecording)
    }
    
    func testScriptFormattedDuration() {
        // Given
        let script = SelftalkScript.create(
            scriptText: "Test",
            category: nil,
            repetitions: 1,
            privacyMode: false,
            in: context
        )
        
        // Test various durations
        let testCases: [(TimeInterval, String)] = [
            (0, "0:00"),
            (1, "0:01"),
            (30, "0:30"),
            (59, "0:59"),
            (60, "1:00"),
            (90, "1:30"),
            (3599, "59:59"),
            (3600, "60:00")
        ]
        
        for (duration, expected) in testCases {
            script.audioDuration = duration
            XCTAssertEqual(script.formattedDuration, expected)
        }
    }
    
    func testScriptFormattedTotalDuration() {
        // Given
        let script = SelftalkScript.create(
            scriptText: "Test",
            category: nil,
            repetitions: 3,
            privacyMode: false,
            in: context
        )
        
        // When - Set duration and interval
        script.audioDuration = 10 // 10 seconds
        script.intervalSeconds = 2 // 2 second interval
        script.repetitions = 3
        
        // Then - Total = (10 * 3) + (2 * 2) = 34 seconds
        XCTAssertEqual(script.formattedTotalDuration, "0:34")
    }
    
    func testScriptIncrementPlayCount() {
        // Given
        let script = SelftalkScript.create(
            scriptText: "Test",
            category: nil,
            repetitions: 1,
            privacyMode: false,
            in: context
        )
        
        XCTAssertEqual(script.playCount, 0)
        XCTAssertNil(script.lastPlayedAt)
        
        // When
        script.incrementPlayCount()
        
        // Then
        XCTAssertEqual(script.playCount, 1)
        XCTAssertNotNil(script.lastPlayedAt)
        
        let firstPlayDate = script.lastPlayedAt
        
        // When - Increment again
        Thread.sleep(forTimeInterval: 0.1)
        script.incrementPlayCount()
        
        // Then
        XCTAssertEqual(script.playCount, 2)
        XCTAssertNotEqual(script.lastPlayedAt, firstPlayDate)
    }
    
    func testScriptTranscriptionLanguageDefault() {
        // Given
        let script = SelftalkScript.create(
            scriptText: "Test",
            category: nil,
            repetitions: 1,
            privacyMode: false,
            in: context
        )
        
        // Then - Should default to en-US
        XCTAssertEqual(script.transcriptionLanguage, "en-US")
    }
    
    func testScriptTranscriptPersistence() {
        // Given
        let script = SelftalkScript.create(
            scriptText: "Test",
            category: nil,
            repetitions: 1,
            privacyMode: false,
            in: context
        )
        
        // When
        script.transcribedText = "This is the transcribed text."
        
        // Then
        XCTAssertEqual(script.transcribedText, "This is the transcribed text.")
        
        // When - Clear transcript
        script.transcribedText = nil
        XCTAssertNil(script.transcribedText)
    }
    
    // MARK: - Category Tests
    
    func testCategoryCreation() {
        // When
        let category = Category(context: context)
        category.id = UUID()
        category.name = "Work"
        category.createdAt = Date()
        category.sortOrder = 0
        
        // Then
        XCTAssertNotNil(category)
        XCTAssertEqual(category.name, "Work")
        XCTAssertNotNil(category.id)
        XCTAssertNotNil(category.createdAt)
        XCTAssertEqual(category.sortOrder, 0)
    }
    
    func testCategoryScriptRelationship() {
        // Given
        let category = Category(context: context)
        category.id = UUID()
        category.name = "Health"
        category.createdAt = Date()
        
        let script1 = SelftalkScript.create(
            scriptText: "Script 1",
            category: category,
            repetitions: 1,
            privacyMode: false,
            in: context
        )
        
        let script2 = SelftalkScript.create(
            scriptText: "Script 2",
            category: category,
            repetitions: 1,
            privacyMode: false,
            in: context
        )
        
        // Then
        XCTAssertEqual(script1.category, category)
        XCTAssertEqual(script2.category, category)
        XCTAssertNotNil(category.scripts)
        XCTAssertEqual(category.scripts?.count, 2)
    }
    
    func testCategorySortOrder() {
        // Given
        let category1 = Category(context: context)
        category1.id = UUID()
        category1.name = "First"
        category1.createdAt = Date()
        category1.sortOrder = 0
        
        let category2 = Category(context: context)
        category2.id = UUID()
        category2.name = "Second"
        category2.createdAt = Date()
        category2.sortOrder = 1
        
        let category3 = Category(context: context)
        category3.id = UUID()
        category3.name = "Third"
        category3.createdAt = Date()
        category3.sortOrder = 2
        
        // When
        let categories = [category3, category1, category2].sorted { $0.sortOrder < $1.sortOrder }
        
        // Then
        XCTAssertEqual(categories[0].name, "First")
        XCTAssertEqual(categories[1].name, "Second")
        XCTAssertEqual(categories[2].name, "Third")
    }
    
    func testScriptWithoutCategory() {
        // Given
        let script = SelftalkScript.create(
            scriptText: "No category",
            category: nil,
            repetitions: 1,
            privacyMode: false,
            in: context
        )
        
        // Then
        XCTAssertNil(script.category)
    }
    
    func testCategoryDeletion() {
        // Given
        let category = Category(context: context)
        category.id = UUID()
        category.name = "To Delete"
        category.createdAt = Date()
        
        let script = SelftalkScript.create(
            scriptText: "Script",
            category: category,
            repetitions: 1,
            privacyMode: false,
            in: context
        )
        
        XCTAssertNotNil(script.category)
        
        // When - Delete category
        context.delete(category)
        
        // Then - Script's category should be nil (nullify delete rule)
        XCTAssertNil(script.category)
    }
    
    // MARK: - Data Validation Tests
    
    func testScriptRequiredFields() {
        // Given
        let script = SelftalkScript(context: context)
        
        // When - Set only required fields
        script.id = UUID()
        script.scriptText = "Required text"
        script.createdAt = Date()
        script.updatedAt = Date()
        script.repetitions = 1
        script.intervalSeconds = 2
        script.privacyModeEnabled = false
        script.playCount = 0
        
        // Then - Should be valid
        XCTAssertNotNil(script.scriptText)
        XCTAssertGreaterThan(script.repetitions, 0)
    }
    
    func testDefaultValues() {
        // Given
        let script = SelftalkScript.create(
            scriptText: "Test defaults",
            category: nil,
            repetitions: 3,
            privacyMode: true,
            in: context
        )
        
        // Then - Check defaults
        XCTAssertEqual(script.intervalSeconds, 2.0)
        XCTAssertEqual(script.playCount, 0)
        XCTAssertNil(script.lastPlayedAt)
        XCTAssertNil(script.audioFilePath)
        XCTAssertEqual(script.audioDuration, 0)
        XCTAssertEqual(script.transcriptionLanguage, "en-US")
    }
}