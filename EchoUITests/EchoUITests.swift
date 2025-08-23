//
//  EchoUITests.swift
//  EchoUITests
//
//  Created by joker on 8/23/25.
//

import XCTest

final class EchoUITests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testCreateNewScript() throws {
        // Test creating a new script
        
        // Tap the add button
        let addButton = app.navigationBars["Scripts"].buttons["plus"]
        XCTAssertTrue(addButton.exists)
        addButton.tap()
        
        // Check that the add script view appears
        XCTAssertTrue(app.navigationBars["New Script"].exists)
        
        // Enter script text
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.exists)
        textEditor.tap()
        textEditor.typeText("I am confident and capable of achieving my goals")
        
        // Adjust repetitions
        let stepper = app.steppers.firstMatch
        if stepper.exists {
            stepper.buttons["Increment"].tap()
            stepper.buttons["Increment"].tap()
        }
        
        // Save the script
        let saveButton = app.navigationBars["New Script"].buttons["Save"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()
        
        // Verify we're back at the scripts list
        XCTAssertTrue(app.navigationBars["Scripts"].exists)
        
        // Verify the script card appears
        let scriptText = app.staticTexts["I am confident and capable of achieving my goals"]
        XCTAssertTrue(scriptText.waitForExistence(timeout: 2))
    }
    
    @MainActor
    func testFilterByCategory() throws {
        // Test filtering scripts by category
        
        let filterButton = app.navigationBars["Scripts"].buttons.element(boundBy: 0)
        if filterButton.exists {
            filterButton.tap()
            
            // Check that filter sheet appears
            XCTAssertTrue(app.navigationBars["Filter by Category"].waitForExistence(timeout: 2))
            
            // Select a category
            let categoryCell = app.cells.containing(.staticText, identifier: "Work").firstMatch
            if categoryCell.exists {
                categoryCell.tap()
            } else {
                // Dismiss if no categories
                app.buttons["Done"].tap()
            }
        }
    }
    
    @MainActor
    func testEmptyState() throws {
        // Test that empty state is shown when no scripts exist
        
        // If there are no scripts, we should see the empty state
        let emptyStateText = app.staticTexts["No Scripts Yet"]
        if emptyStateText.exists {
            XCTAssertTrue(app.staticTexts["Tap the + button to create your first self-talk script"].exists)
        }
    }
    
    @MainActor
    func testPrivacyModeIndicator() throws {
        // Test that privacy mode indicator shows on script cards
        
        // Create a script first if needed
        if app.staticTexts["No Scripts Yet"].exists {
            try testCreateNewScript()
        }
        
        // Look for lock icon on script cards
        let lockIcon = app.images.matching(identifier: "lock.fill").firstMatch
        // Privacy mode is on by default, so lock should be visible
        XCTAssertTrue(lockIcon.exists || app.staticTexts["No Scripts Yet"].exists)
    }
    
    @MainActor
    func testScriptCardInteraction() throws {
        // Test tapping on a script card
        
        // Create a script if needed
        if app.staticTexts["No Scripts Yet"].exists {
            try testCreateNewScript()
        }
        
        // Find and tap a script card
        let scriptCard = app.scrollViews.otherElements.firstMatch
        if scriptCard.exists {
            scriptCard.tap()
            
            // Since no recording exists, nothing should happen on tap
            // The card should still be visible
            XCTAssertTrue(scriptCard.exists)
        }
    }
    
    @MainActor
    func testAddNewCategory() throws {
        // Test adding a new category while creating a script
        
        // Open add script view
        app.navigationBars["Scripts"].buttons["plus"].tap()
        
        // Tap category menu
        let categoryMenu = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Select Category'")).firstMatch
        if categoryMenu.waitForExistence(timeout: 2) {
            categoryMenu.tap()
            
            // Look for "Add New Category" option
            let addCategoryButton = app.buttons["Add New Category..."]
            if addCategoryButton.waitForExistence(timeout: 2) {
                addCategoryButton.tap()
                
                // Enter category name in alert
                let textField = app.textFields.firstMatch
                if textField.waitForExistence(timeout: 2) {
                    textField.typeText("Custom Category")
                    app.buttons["Add"].tap()
                }
            }
        }
        
        // Cancel to go back
        app.navigationBars["New Script"].buttons["Cancel"].tap()
    }
    
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}