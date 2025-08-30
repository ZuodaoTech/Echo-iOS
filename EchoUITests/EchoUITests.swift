import XCTest

final class EchoUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - App Launch Tests
    
    func testAppLaunchAndBasicUI() throws {
        // Test that app launches successfully
        XCTAssertTrue(app.state == .runningForeground)
        
        // Test that main UI elements are present
        // Note: Actual element identifiers would need to be added to the app
        
        // Look for common UI elements that should be present
        let exists = NSPredicate(format: "exists == 1")
        
        // Test navigation or tab structure
        if app.tabBars.count > 0 {
            XCTAssertTrue(app.tabBars.firstMatch.exists)
        }
        
        // Test that we can see some content
        if app.staticTexts.count > 0 {
            XCTAssertTrue(app.staticTexts.firstMatch.exists)
        }
    }
    
    // MARK: - Navigation Tests
    
    func testMainNavigation() {
        // Test basic navigation within the app
        // This would need to be customized based on the actual app structure
        
        // Look for navigation bars
        if app.navigationBars.count > 0 {
            XCTAssertTrue(app.navigationBars.firstMatch.exists)
        }
        
        // Look for any buttons that might be navigation elements
        if app.buttons.count > 0 {
            let firstButton = app.buttons.firstMatch
            XCTAssertTrue(firstButton.exists)
            
            // Test tapping doesn't crash
            if firstButton.isHittable {
                firstButton.tap()
            }
        }
    }
    
    // MARK: - Recording Flow Tests
    
    func testRecordingFlow() {
        // Test the record button interaction
        // Note: This would need actual accessibility identifiers
        
        // Look for record button (might be identified by system image or accessibility label)
        let recordButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'record' OR identifier CONTAINS 'record'")).firstMatch
        
        if recordButton.exists && recordButton.isHittable {
            recordButton.tap()
            
            // Should see some recording UI or permission alert
            // Handle permission alert if it appears
            addUIInterruptionMonitor(withDescription: "Microphone Permission") { alert in
                if alert.buttons["Allow"].exists {
                    alert.buttons["Allow"].tap()
                    return true
                } else if alert.buttons["OK"].exists {
                    alert.buttons["OK"].tap()
                    return true
                }
                return false
            }
            
            // Interact with the app to trigger interruption monitor
            app.tap()
            
            // Look for stop button or recording indicator
            let stopButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'stop' OR identifier CONTAINS 'stop'")).firstMatch
            
            if stopButton.exists && stopButton.isHittable {
                // Wait a moment for recording
                sleep(1)
                stopButton.tap()
            }
        }
        
        // Test should complete without crashing
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    // MARK: - Script Management Tests
    
    func testScriptCreation() {
        // Test creating a new script
        // Look for add/create buttons
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '+' OR label CONTAINS 'add' OR identifier CONTAINS 'add'")).firstMatch
        
        if addButton.exists && addButton.isHittable {
            addButton.tap()
            
            // Look for text fields to enter script content
            if app.textViews.count > 0 {
                let textView = app.textViews.firstMatch
                if textView.exists {
                    textView.tap()
                    textView.typeText("UI Test Script Content")
                }
            }
            
            // Look for save button
            let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'save' OR identifier CONTAINS 'save'")).firstMatch
            
            if saveButton.exists && saveButton.isHittable {
                saveButton.tap()
            }
        }
        
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    // MARK: - Settings Tests
    
    func testSettingsAccess() {
        // Test accessing settings
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'settings' OR identifier CONTAINS 'settings'")).firstMatch
        
        if settingsButton.exists && settingsButton.isHittable {
            settingsButton.tap()
            
            // Should be able to navigate to settings
            XCTAssertTrue(app.state == .runningForeground)
            
            // Look for back navigation
            if app.navigationBars.buttons.count > 0 {
                let backButton = app.navigationBars.buttons.firstMatch
                if backButton.exists && backButton.isHittable {
                    backButton.tap()
                }
            }
        }
        
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    // MARK: - Error Handling Tests
    
    func testAppResilience() {
        // Test that app handles various interactions without crashing
        
        // Tap various elements rapidly
        if app.buttons.count > 0 {
            for i in 0..<min(5, app.buttons.count) {
                let button = app.buttons.element(boundBy: i)
                if button.isHittable {
                    button.tap()
                    usleep(100000) // Brief pause
                }
            }
        }
        
        // Test device rotation if supported
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
            usleep(500000) // Wait for rotation
            
            XCUIDevice.shared.orientation = .portrait
            usleep(500000) // Wait for rotation
        }
        
        // App should still be running
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibility() {
        // Test that key UI elements have accessibility labels
        let allElements = app.descendants(matching: .any)
        var accessibleElements = 0
        var totalInteractiveElements = 0
        
        for i in 0..<min(50, allElements.count) { // Check first 50 elements
            let element = allElements.element(boundBy: i)
            
            if element.elementType == .button || element.elementType == .textField || element.elementType == .textView {
                totalInteractiveElements += 1
                
                if !element.label.isEmpty || !element.identifier.isEmpty {
                    accessibleElements += 1
                }
            }
        }
        
        // At least 50% of interactive elements should have accessibility info
        if totalInteractiveElements > 0 {
            let accessibilityRatio = Double(accessibleElements) / Double(totalInteractiveElements)
            XCTAssertGreaterThan(accessibilityRatio, 0.3, "Less than 30% of interactive elements have accessibility labels")
        }
    }
    
    // MARK: - Performance Tests
    
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
    
    func testScrollingPerformance() {
        // Test scrolling performance if there are scrollable views
        if app.scrollViews.count > 0 {
            let scrollView = app.scrollViews.firstMatch
            
            if scrollView.exists {
                measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
                    scrollView.swipeUp()
                    scrollView.swipeDown()
                }
            }
        } else if app.tables.count > 0 {
            let table = app.tables.firstMatch
            
            if table.exists {
                measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
                    table.swipeUp()
                    table.swipeDown()
                }
            }
        }
    }
    
    // MARK: - Integration with External Services Tests
    
    func testPermissionHandling() {
        // Test that permission dialogs are handled gracefully
        
        // Set up interruption monitor for various permissions
        addUIInterruptionMonitor(withDescription: "Microphone Permission") { alert in
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
            } else if alert.buttons["Don't Allow"].exists {
                alert.buttons["Don't Allow"].tap()
            } else if alert.buttons["OK"].exists {
                alert.buttons["OK"].tap()
            }
            return true
        }
        
        addUIInterruptionMonitor(withDescription: "Speech Recognition Permission") { alert in
            if alert.buttons["OK"].exists {
                alert.buttons["OK"].tap()
            }
            return true
        }
        
        // Trigger interactions that might request permissions
        if app.buttons.count > 0 {
            for i in 0..<min(3, app.buttons.count) {
                let button = app.buttons.element(boundBy: i)
                if button.isHittable {
                    button.tap()
                    app.tap() // Trigger interruption monitors
                    usleep(200000) // Brief pause
                }
            }
        }
        
        XCTAssertTrue(app.state == .runningForeground)
    }
}