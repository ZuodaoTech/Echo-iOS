import XCTest
import CoreData
@testable import Pando_Echo

class CoreDataTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }
    
    override func tearDown() {
        persistenceController = nil
        context = nil
        super.tearDown()
    }
    
    // MARK: - Category Tests
    
    func testCreateCategory() {
        let category = Category(context: context)
        category.id = UUID()
        category.name = "Test Category"
        category.createdAt = Date()
        category.sortOrder = 0
        
        XCTAssertNotNil(category)
        XCTAssertEqual(category.name, "Test Category")
        XCTAssertEqual(category.sortOrder, 0)
        
        do {
            try context.save()
        } catch {
            XCTFail("Failed to save category: \(error)")
        }
    }
    
    func testCreateDefaultCategories() {
        Category.createDefaultCategories(context: context)
        
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        
        do {
            let categories = try context.fetch(request)
            XCTAssertEqual(categories.count, 5)
            
            let categoryNames = categories.map { $0.name }
            XCTAssertTrue(categoryNames.contains("Breaking Bad Habits"))
            XCTAssertTrue(categoryNames.contains("Building Good Habits"))
            XCTAssertTrue(categoryNames.contains("Appropriate Positivity"))
            XCTAssertTrue(categoryNames.contains("Personal"))
            XCTAssertTrue(categoryNames.contains("Work"))
        } catch {
            XCTFail("Failed to fetch categories: \(error)")
        }
    }
    
    // MARK: - SelftalkScript Tests
    
    func testCreateSelftalkScript() {
        let category = Category(context: context)
        category.id = UUID()
        category.name = "Test Category"
        category.createdAt = Date()
        
        let script = SelftalkScript.create(
            scriptText: "I am confident and capable",
            category: category,
            repetitions: 5,
            privacyMode: true,
            in: context
        )
        
        XCTAssertNotNil(script)
        XCTAssertEqual(script.scriptText, "I am confident and capable")
        XCTAssertEqual(script.repetitions, 5)
        XCTAssertTrue(script.privacyModeEnabled)
        XCTAssertEqual(script.category, category)
        XCTAssertEqual(script.playCount, 0)
        XCTAssertNil(script.audioFilePath)
        XCTAssertNil(script.lastPlayedAt)
        
        do {
            try context.save()
        } catch {
            XCTFail("Failed to save script: \(error)")
        }
    }
    
    func testScriptPreview() {
        let longText = String(repeating: "This is a long text. ", count: 10)
        let script = SelftalkScript.create(
            scriptText: longText,
            category: nil,
            in: context
        )
        
        let preview = script.scriptPreview
        XCTAssertTrue(preview.count <= 103) // 100 + "..."
        XCTAssertTrue(preview.hasSuffix("..."))
    }
    
    func testScriptPreviewShortText() {
        let shortText = "Short text"
        let script = SelftalkScript.create(
            scriptText: shortText,
            category: nil,
            in: context
        )
        
        let preview = script.scriptPreview
        XCTAssertEqual(preview, shortText)
        XCTAssertFalse(preview.hasSuffix("..."))
    }
    
    func testIncrementPlayCount() {
        let script = SelftalkScript.create(
            scriptText: "Test script",
            category: nil,
            in: context
        )
        
        XCTAssertEqual(script.playCount, 0)
        XCTAssertNil(script.lastPlayedAt)
        
        script.incrementPlayCount()
        
        XCTAssertEqual(script.playCount, 1)
        XCTAssertNotNil(script.lastPlayedAt)
        
        script.incrementPlayCount()
        XCTAssertEqual(script.playCount, 2)
    }
    
    func testCategoryScriptsRelationship() {
        let category = Category(context: context)
        category.id = UUID()
        category.name = "Test Category"
        category.createdAt = Date()
        
        let script1 = SelftalkScript.create(
            scriptText: "Script 1",
            category: category,
            in: context
        )
        
        let script2 = SelftalkScript.create(
            scriptText: "Script 2",
            category: category,
            in: context
        )
        
        do {
            try context.save()
        } catch {
            XCTFail("Failed to save: \(error)")
        }
        
        let scripts = category.scriptsArray
        XCTAssertEqual(scripts.count, 2)
        XCTAssertTrue(scripts.contains(script1))
        XCTAssertTrue(scripts.contains(script2))
    }
    
    func testDefaultPrivacyMode() {
        let script = SelftalkScript.create(
            scriptText: "Test",
            category: nil,
            in: context
        )
        
        XCTAssertTrue(script.privacyModeEnabled, "Privacy mode should be enabled by default")
    }
    
    func testHasRecording() {
        let script = SelftalkScript.create(
            scriptText: "Test",
            category: nil,
            in: context
        )
        
        XCTAssertFalse(script.hasRecording, "New script should not have recording")
        
        script.audioFilePath = "/fake/path/audio.m4a"
        XCTAssertFalse(script.hasRecording, "Non-existent file should return false")
    }
}