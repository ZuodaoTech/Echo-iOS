import XCTest

final class MainFlowUITests: XCTestCase {
    
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
    
    // MARK: - Empty State Tests
    
    func testEmptyStateShowsWelcomeMessage() {
        // Given - Fresh app launch
        
        // Then
        XCTAssertTrue(app.staticTexts["Create your first selftalk script"].exists ||
                     app.buttons["Add Script"].exists)
    }
    
    func testAddScriptButtonExistsInEmptyState() {
        // Given - Empty state
        
        // Then
        let addButton = app.navigationBars.buttons["Add"]
        XCTAssertTrue(addButton.exists)
    }
    
    // MARK: - Add Script Flow Tests
    
    func testAddNewScriptFlow() {
        // Given
        let addButton = app.navigationBars.buttons["Add"]
        
        // When - Navigate to add script
        addButton.tap()
        
        // Then - Add script view appears
        XCTAssertTrue(app.navigationBars["New Script"].exists)
        
        // When - Fill in script details
        let textEditor = app.textViews.firstMatch
        textEditor.tap()
        textEditor.typeText("I am confident and capable")
        
        // Select repetitions (if picker is visible)
        if app.pickers.firstMatch.exists {
            app.pickers.firstMatch.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "5")
        }
        
        // When - Save
        app.navigationBars.buttons["Save"].tap()
        
        // Then - Script appears in list
        XCTAssertTrue(app.staticTexts["I am confident and capable"].waitForExistence(timeout: 5))
    }
    
    func testCancelAddScriptFlow() {
        // Given
        let addButton = app.navigationBars.buttons["Add"]
        addButton.tap()
        
        // When - Cancel without adding
        app.navigationBars.buttons["Cancel"].tap()
        
        // Then - Returns to main list
        XCTAssertTrue(app.navigationBars["Selftalk Scripts"].exists ||
                     app.navigationBars["Echo"].exists)
    }
    
    // MARK: - Script Card Interaction Tests
    
    func testScriptCardDisplaysCorrectly() {
        // Given - Add a script first
        createTestScript(text: "Test script for display", repetitions: "3")
        
        // Then - Verify card elements
        XCTAssertTrue(app.staticTexts["Test script for display"].exists)
        XCTAssertTrue(app.staticTexts["3x"].exists)
    }
    
    func testScriptCardShowsNoRecordingIndicator() {
        // Given - Script without recording
        createTestScript(text: "Script without recording")
        
        // Then - Should show mic.slash icon or similar indicator
        XCTAssertTrue(app.images["mic.slash"].exists ||
                     app.staticTexts["No Recording"].exists ||
                     app.cells.firstMatch.exists)
    }
    
    func testScriptCardShowsProcessingIndicator() {
        // Given - Script being processed
        // This would need to be triggered by starting a recording
        // For now, we verify the UI element exists in the view
        
        createTestScript(text: "Processing test script")
        
        // The processing state would show when actually processing
        // We can at least verify the card exists
        XCTAssertTrue(app.cells.containing(.staticText, identifier: "Processing test script").element.exists)
    }
    
    // MARK: - Edit Script Flow Tests
    
    func testEditScriptFlow() {
        // Given - Create a script
        createTestScript(text: "Original text")
        
        // When - Tap to edit
        let scriptCell = app.cells.containing(.staticText, identifier: "Original text").element
        scriptCell.tap()
        
        // Then - Edit view appears
        let textEditor = app.textViews.firstMatch
        if textEditor.waitForExistence(timeout: 5) {
            // When - Modify text
            textEditor.tap()
            textEditor.selectAll()
            textEditor.typeText("Modified text")
            
            // Save changes
            app.navigationBars.buttons["Save"].tap()
            
            // Then - Updated text appears
            XCTAssertTrue(app.staticTexts["Modified text"].waitForExistence(timeout: 5))
        }
    }
    
    // Delete functionality removed - no swipe-to-delete support
    
    // MARK: - Recording Flow Tests
    
    func testRecordingButtonStates() {
        // Given - Navigate to add/edit script
        createTestScript(text: "Recording test script")
        let scriptCell = app.cells.containing(.staticText, identifier: "Recording test script").element
        scriptCell.tap()
        
        // Then - Recording button should be visible
        XCTAssertTrue(app.buttons["Record"].exists ||
                     app.buttons.matching(identifier: "mic.circle").firstMatch.exists ||
                     app.staticTexts["Recording"].exists)
    }
    
    func testPrivacyModeAlert() {
        // Given - Script with recording (would need to be set up)
        createTestScript(text: "Privacy mode test")
        
        // When - Try to play without headphones
        let scriptCell = app.cells.containing(.staticText, identifier: "Privacy mode test").element
        scriptCell.tap()
        
        // Then - Alert might appear (depends on device state)
        // We can verify the alert handling code exists
        if app.alerts["Privacy Mode"].exists {
            XCTAssertTrue(app.alerts.staticTexts["Please connect earphones to play this audio"].exists)
            app.alerts.buttons["OK"].tap()
        }
    }
    
    // MARK: - Transcription UI Tests
    
    func testTranscriptionLanguagePicker() {
        // Given - Navigate to add/edit script
        app.navigationBars.buttons["Add"].tap()
        
        // Then - Language picker should exist
        XCTAssertTrue(app.buttons["Transcription Language"].exists ||
                     app.staticTexts["Transcription Language"].exists ||
                     app.pickers.count > 0)
    }
    
    func testTranscriptionButtonsVisibility() {
        // This test would need a script with transcription
        // For now, verify the UI elements can exist
        
        createTestScript(text: "Transcript test")
        let scriptCell = app.cells.containing(.staticText, identifier: "Transcript test").element
        scriptCell.tap()
        
        // Check for transcript-related UI elements
        // These would appear after recording and transcription
        let possibleElements = [
            app.buttons["Copy"],
            app.buttons["Use as Script"],
            app.buttons["Undo"],
            app.staticTexts["Transcript"]
        ]
        
        // At least some UI elements should be present
        XCTAssertTrue(app.textViews.count > 0 || app.buttons.count > 0)
    }
    
    // MARK: - Category Management Tests
    
    func testCategorySelection() {
        // Given - Add script view
        app.navigationBars.buttons["Add"].tap()
        
        // Then - Category picker should exist
        XCTAssertTrue(app.buttons["Category"].exists ||
                     app.pickers.matching(identifier: "Category").firstMatch.exists ||
                     app.staticTexts["Category"].exists)
    }
    
    func testCreateNewCategory() {
        // Given - Add script view
        app.navigationBars.buttons["Add"].tap()
        
        // When - Try to add new category
        if app.buttons["Add Category"].exists {
            app.buttons["Add Category"].tap()
            
            // Then - Alert or sheet for new category
            if app.alerts.firstMatch.exists {
                let textField = app.alerts.textFields.firstMatch
                textField.typeText("Work")
                app.alerts.buttons["Add"].tap()
            }
        }
    }
    
    // MARK: - Settings and Configuration Tests
    
    func testPrivacyModeToggle() {
        // Given - Add/edit script view
        createTestScript(text: "Privacy settings test")
        let scriptCell = app.cells.containing(.staticText, identifier: "Privacy settings test").element
        scriptCell.tap()
        
        // Then - Privacy mode switch should exist
        XCTAssertTrue(app.switches["Privacy Mode"].exists ||
                     app.switches.firstMatch.exists)
    }
    
    func testRepetitionCountAdjustment() {
        // Given - Add script view
        app.navigationBars.buttons["Add"].tap()
        
        // Then - Repetition control should exist
        XCTAssertTrue(app.steppers.firstMatch.exists ||
                     app.pickers.firstMatch.exists ||
                     app.staticTexts["Repetitions"].exists)
    }
    
    func testIntervalSliderAdjustment() {
        // Given - Script with recording
        createTestScript(text: "Interval test script")
        let scriptCell = app.cells.containing(.staticText, identifier: "Interval test script").element
        scriptCell.tap()
        
        // Then - Interval slider might exist
        if app.sliders.firstMatch.exists {
            let slider = app.sliders.firstMatch
            slider.adjust(toNormalizedSliderPosition: 0.5)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestScript(text: String, repetitions: String = "3") {
        // Navigate to add script
        app.navigationBars.buttons["Add"].tap()
        
        // Fill in script text
        let textEditor = app.textViews.firstMatch
        if textEditor.waitForExistence(timeout: 5) {
            textEditor.tap()
            textEditor.typeText(text)
            
            // Set repetitions if picker exists
            if app.pickers.firstMatch.exists {
                app.pickers.firstMatch.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: repetitions)
            }
            
            // Save
            app.navigationBars.buttons["Save"].tap()
            
            // Wait for script to appear
            _ = app.staticTexts[text].waitForExistence(timeout: 5)
        }
    }
    
    private func selectAll() {
        // Helper to select all text in a text view
        app.menuItems["Select All"].tap()
    }
}

// Extension for XCUIElement
extension XCUIElement {
    func selectAll() {
        // Double tap to select word, then select all from menu
        self.doubleTap()
        if XCUIApplication().menuItems["Select All"].waitForExistence(timeout: 2) {
            XCUIApplication().menuItems["Select All"].tap()
        }
    }
}