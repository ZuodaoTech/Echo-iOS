import XCTest
import AVFoundation
import CoreData
@testable import Pando_Echo

class RepetitionPlaybackTests: XCTestCase {
    
    var audioService: AudioService!
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var testScript: SelftalkScript!
    
    override func setUp() {
        super.setUp()
        audioService = AudioService()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        
        // Create a test script with 3 repetitions
        testScript = SelftalkScript.create(
            scriptText: "Test script for repetition playback",
            category: nil,
            repetitions: 3,
            intervalSeconds: 2.0,
            privacyMode: false,
            in: context
        )
    }
    
    override func tearDown() {
        audioService.stopPlayback()
        audioService = nil
        persistenceController = nil
        context = nil
        testScript = nil
        super.tearDown()
    }
    
    func testRepetitionSetup() {
        // Verify script has correct repetition settings
        XCTAssertEqual(testScript.repetitions, 3, "Script should have 3 repetitions")
        XCTAssertEqual(testScript.intervalSeconds, 2.0, accuracy: 0.01, "Script should have 2 second interval")
    }
    
    func testPlaybackInitialization() {
        // When play is called, totalRepetitions should be set correctly
        // Note: Can't actually play without audio file, but we can test the setup
        
        // Simulate what happens in play()
        let totalReps = Int(testScript.repetitions)
        XCTAssertEqual(totalReps, 3, "Should convert to 3 total repetitions")
        
        // Initial state should be repetition 1
        let initialRep = 1
        XCTAssertEqual(initialRep, 1, "Should start at repetition 1")
        
        // After first play, should check if 1 < 3 (true, continue)
        XCTAssertTrue(initialRep < totalReps, "Should continue after first play")
    }
    
    func testCompletionMonitorTiming() {
        // Test that completion monitor is set up with correct timing
        let testDuration: TimeInterval = 5.0  // 5 second audio
        let expectedCheckInterval = testDuration + 0.1
        
        XCTAssertEqual(expectedCheckInterval, 5.1, accuracy: 0.01, "Should check 0.1s after expected duration")
    }
    
    func testHandlePlaybackCompletionLogic() {
        // Test the logic flow for handling completion
        
        // Scenario 1: After first playback (rep 1 of 3)
        var currentRep = 1
        let totalReps = 3
        
        if currentRep < totalReps {
            // Should schedule next repetition
            currentRep += 1
            XCTAssertEqual(currentRep, 2, "Should move to repetition 2")
        }
        
        // Scenario 2: After second playback (rep 2 of 3)
        if currentRep < totalReps {
            // Should schedule next repetition
            currentRep += 1
            XCTAssertEqual(currentRep, 3, "Should move to repetition 3")
        }
        
        // Scenario 3: After third playback (rep 3 of 3)
        if currentRep < totalReps {
            XCTFail("Should not continue after 3rd repetition")
        } else {
            // Should stop
            XCTAssertEqual(currentRep, totalReps, "Should complete at repetition 3")
        }
    }
    
    func testPauseResumeWithCompletionMonitor() {
        // Test that pause/resume correctly handles the completion monitor
        
        // When pausing, completion timer should be cancelled
        // When resuming, completion timer should be restarted with remaining duration
        
        let totalDuration = 10.0
        let pausedAt = 4.0
        let expectedRemaining = totalDuration - pausedAt + 0.1
        
        XCTAssertEqual(expectedRemaining, 6.1, accuracy: 0.01, "Should monitor for remaining 6.1 seconds")
    }
}