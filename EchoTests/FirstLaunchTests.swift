import XCTest
import CoreData
@testable import Echo

class FirstLaunchTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        // Clear UserDefaults for testing
        UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")
        
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")
        persistenceController = nil
        context = nil
        super.tearDown()
    }
    
    func testSampleScriptsCreation() {
        // Create categories first
        Category.createDefaultCategories(context: context)
        
        do {
            try context.save()
            
            // Fetch categories
            let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
            let allCategories = try context.fetch(categoryRequest)
            
            // Create sample scripts like in the app
            if let breakingBadHabits = allCategories.first(where: { $0.name == "Breaking Bad Habits" }) {
                _ = SelftalkScript.create(
                    scriptText: "I never smoke, because it stinks, and I hate being controlled.",
                    category: breakingBadHabits,
                    repetitions: 3,
                    privacyMode: true,
                    in: context
                )
            }
            
            if let buildingGoodHabits = allCategories.first(where: { $0.name == "Building Good Habits" }) {
                _ = SelftalkScript.create(
                    scriptText: "I always go to bed before 10 p.m., because it's healthier, and I love waking up with a great deal of energy.",
                    category: buildingGoodHabits,
                    repetitions: 3,
                    privacyMode: true,
                    in: context
                )
            }
            
            if let appropriatePositivity = allCategories.first(where: { $0.name == "Appropriate Positivity" }) {
                _ = SelftalkScript.create(
                    scriptText: "I made a few mistakes, but I also did several things well. Mistakes are a normal part of learning, and I can use them as an opportunity to improve. Most people are likely focused on the overall effort or result, not just the small errors.",
                    category: appropriatePositivity,
                    repetitions: 3,
                    privacyMode: true,
                    in: context
                )
            }
            
            try context.save()
            
            // Verify scripts were created
            let scriptRequest: NSFetchRequest<SelftalkScript> = SelftalkScript.fetchRequest()
            let scripts = try context.fetch(scriptRequest)
            
            XCTAssertEqual(scripts.count, 3, "Should have 3 sample scripts")
            
            // Verify script content
            let smokeScript = scripts.first { $0.scriptText.contains("never smoke") }
            XCTAssertNotNil(smokeScript)
            XCTAssertEqual(smokeScript?.category?.name, "Breaking Bad Habits")
            XCTAssertTrue(smokeScript?.privacyModeEnabled ?? false)
            
            let sleepScript = scripts.first { $0.scriptText.contains("go to bed") }
            XCTAssertNotNil(sleepScript)
            XCTAssertEqual(sleepScript?.category?.name, "Building Good Habits")
            
            let mistakesScript = scripts.first { $0.scriptText.contains("mistakes") }
            XCTAssertNotNil(mistakesScript)
            XCTAssertEqual(mistakesScript?.category?.name, "Appropriate Positivity")
            
            // All should have privacy mode on by default
            scripts.forEach { script in
                XCTAssertTrue(script.privacyModeEnabled, "All scripts should have privacy mode enabled by default")
                XCTAssertEqual(script.repetitions, 3, "All scripts should have 3 repetitions")
            }
            
        } catch {
            XCTFail("Failed to create sample scripts: \(error)")
        }
    }
    
    func testFirstLaunchFlag() {
        // Initially should be false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasLaunchedBefore"))
        
        // Set it to true
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        
        // Now should be true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasLaunchedBefore"))
    }
    
    func testCategoriesCreatedCorrectly() {
        Category.createDefaultCategories(context: context)
        
        do {
            try context.save()
            
            let request: NSFetchRequest<Category> = Category.fetchRequest()
            let categories = try context.fetch(request)
            
            XCTAssertEqual(categories.count, 5)
            
            let expectedCategories = [
                "Breaking Bad Habits",
                "Building Good Habits",
                "Appropriate Positivity",
                "Personal",
                "Work"
            ]
            
            let categoryNames = categories.map { $0.name }
            expectedCategories.forEach { expected in
                XCTAssertTrue(categoryNames.contains(expected), "Should contain category: \(expected)")
            }
            
        } catch {
            XCTFail("Failed to test categories: \(error)")
        }
    }
}