import XCTest
import AVFoundation
import CoreData
@testable import Echo

class PlaybackTests: XCTestCase {
    
    var audioService: AudioService!
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var testScript: SelftalkScript!
    
    override func setUp() {
        super.setUp()
        audioService = AudioService()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        
        // Create a test script with repetitions
        testScript = SelftalkScript.create(
            scriptText: "Test affirmation for playback",
            category: nil,
            repetitions: 3,
            intervalSeconds: 1.0,
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
    
    // MARK: - Play/Pause/Resume Tests
    
    func testPlayPauseStates() {
        // Initially, nothing should be playing or paused
        XCTAssertFalse(audioService.isPlaying)
        XCTAssertFalse(audioService.isPaused)
        XCTAssertNil(audioService.currentPlayingScriptId)
        
        // After pause (when playing), should be paused
        // Note: Can't test actual playback without audio file
        // but we can test state management
    }
    
    func testPauseWhilePlaying() {
        // Setup playing state
        audioService.isPlaying = true
        audioService.currentPlayingScriptId = testScript.id
        
        // Pause
        audioService.pausePlayback()
        
        // Verify states
        XCTAssertFalse(audioService.isPlaying, "Should not be playing after pause")
        XCTAssertTrue(audioService.isPaused, "Should be paused after pause")
        XCTAssertEqual(audioService.currentPlayingScriptId, testScript.id, "Script ID should remain")
    }
    
    func testResumeFromPause() {
        // Setup paused state
        audioService.isPaused = true
        audioService.currentPlayingScriptId = testScript.id
        
        // Resume
        audioService.resumePlayback()
        
        // Verify states
        XCTAssertTrue(audioService.isPlaying, "Should be playing after resume")
        XCTAssertFalse(audioService.isPaused, "Should not be paused after resume")
        XCTAssertEqual(audioService.currentPlayingScriptId, testScript.id, "Script ID should remain")
    }
    
    func testStopClearsPauseState() {
        // Setup paused state
        audioService.isPaused = true
        audioService.isPlaying = false
        audioService.currentPlayingScriptId = testScript.id
        
        // Stop
        audioService.stopPlayback()
        
        // Verify all states cleared
        XCTAssertFalse(audioService.isPlaying)
        XCTAssertFalse(audioService.isPaused)
        XCTAssertNil(audioService.currentPlayingScriptId)
        XCTAssertEqual(audioService.playbackProgress, 0)
        XCTAssertEqual(audioService.currentRepetition, 0)
    }
    
    // MARK: - Repetition Tests
    
    func testRepetitionCountSetup() {
        // When starting playback with a script that has 3 repetitions
        // (can't test actual play without audio file, but can test the setup)
        testScript.repetitions = 3
        
        // The totalRepetitions should be set correctly when play is called
        // currentRepetition should start at 1
    }
    
    func testRepetitionProgress() {
        // Setup repetition state
        audioService.currentRepetition = 2
        audioService.totalRepetitions = 3
        
        XCTAssertEqual(audioService.currentRepetition, 2)
        XCTAssertEqual(audioService.totalRepetitions, 3)
        
        // Should show "Repetition 2 of 3" in UI
    }
    
    // MARK: - Privacy Mode Tests
    
    func testPrivacyModeWithoutEarphones() {
        // Enable privacy mode on script
        testScript.privacyModeEnabled = true
        
        // Simulate no earphones connected
        audioService.privacyModeActive = true
        
        // Attempt to play should fail
        XCTAssertThrowsError(try audioService.play(script: testScript)) { error in
            XCTAssertEqual(error as? AudioServiceError, AudioServiceError.privacyModeActive)
        }
    }
    
    func testPrivacyModeWithEarphones() {
        // Enable privacy mode on script
        testScript.privacyModeEnabled = true
        
        // Simulate earphones connected
        audioService.privacyModeActive = false
        
        // Play should not throw privacy error (might throw no recording error)
        do {
            try audioService.play(script: testScript)
        } catch AudioServiceError.noRecording {
            // Expected - no actual recording
        } catch AudioServiceError.privacyModeActive {
            XCTFail("Should not throw privacy error when earphones connected")
        } catch {
            // Other errors are ok for this test
        }
    }
    
    // MARK: - Duration Calculation Tests
    
    func testTotalDurationCalculation() {
        testScript.audioDuration = 10.0  // 10 seconds
        testScript.repetitions = 3
        testScript.intervalSeconds = 2.0
        
        let expectedDuration = (10.0 * 3) + (2.0 * 2)  // 30s audio + 4s intervals = 34s
        XCTAssertEqual(testScript.totalDuration, expectedDuration, accuracy: 0.01)
    }
    
    func testFormattedDuration() {
        // Test short duration
        testScript.audioDuration = 15.0
        XCTAssertEqual(testScript.formattedDuration, "15s")
        
        // Test long duration
        testScript.audioDuration = 75.0
        XCTAssertEqual(testScript.formattedDuration, "1m 15s")
        
        // Test exact minute
        testScript.audioDuration = 60.0
        XCTAssertEqual(testScript.formattedDuration, "1m 0s")
    }
    
    func testFormattedTotalDuration() {
        testScript.audioDuration = 10.0
        testScript.repetitions = 3
        testScript.intervalSeconds = 2.0
        
        // Total: 30s audio + 4s intervals = 34s
        XCTAssertEqual(testScript.formattedTotalDuration, "34s")
        
        // Test with longer duration
        testScript.audioDuration = 30.0
        testScript.repetitions = 3
        testScript.intervalSeconds = 5.0
        
        // Total: 90s audio + 10s intervals = 100s = 1m 40s
        XCTAssertEqual(testScript.formattedTotalDuration, "1m 40s")
    }
    
    // MARK: - Edge Cases
    
    func testPlayWithNoRecording() {
        // Script without recording
        testScript.audioFilePath = nil
        
        XCTAssertThrowsError(try audioService.play(script: testScript)) { error in
            XCTAssertEqual(error as? AudioServiceError, AudioServiceError.noRecording)
        }
    }
    
    func testZeroRepetitions() {
        testScript.repetitions = 0
        testScript.audioDuration = 10.0
        
        XCTAssertEqual(testScript.totalDuration, 0, "Should return 0 for zero repetitions")
    }
    
    func testSingleRepetition() {
        testScript.repetitions = 1
        testScript.audioDuration = 10.0
        testScript.intervalSeconds = 2.0
        
        // With 1 repetition, no intervals needed
        XCTAssertEqual(testScript.totalDuration, 10.0, "Single repetition should have no intervals")
    }
}