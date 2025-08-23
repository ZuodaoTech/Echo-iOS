import XCTest
import AVFoundation
import CoreData
@testable import Echo

class AudioServiceTests: XCTestCase {
    
    var audioService: AudioService!
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var testScript: SelftalkScript!
    
    override func setUp() {
        super.setUp()
        audioService = AudioService()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        
        // Create a test script
        testScript = SelftalkScript.create(
            scriptText: "Test affirmation",
            category: nil,
            repetitions: 3,
            privacyMode: true,
            in: context
        )
    }
    
    override func tearDown() {
        audioService = nil
        persistenceController = nil
        context = nil
        testScript = nil
        super.tearDown()
    }
    
    func testPrivacyModeDetection() {
        // This test verifies the privacy mode check logic
        audioService.checkPrivacyMode()
        
        // In simulator/test environment, no earphones are connected
        // So privacy mode should be active
        XCTAssertTrue(audioService.privacyModeActive, "Privacy mode should be active when no earphones connected")
    }
    
    func testPlayWithPrivacyMode() {
        // Test that playing fails when privacy mode is active and enabled on script
        testScript.privacyModeEnabled = true
        audioService.privacyModeActive = true
        
        XCTAssertThrowsError(try audioService.play(script: testScript)) { error in
            XCTAssertEqual(error as? AudioServiceError, AudioServiceError.privacyModeActive)
        }
    }
    
    func testPlayWithoutRecording() {
        // Test that playing fails when no recording exists
        testScript.privacyModeEnabled = false
        audioService.privacyModeActive = false
        
        XCTAssertThrowsError(try audioService.play(script: testScript)) { error in
            XCTAssertEqual(error as? AudioServiceError, AudioServiceError.noRecording)
        }
    }
    
    func testRecordingStateChanges() {
        XCTAssertFalse(audioService.isRecording, "Should not be recording initially")
        
        // Note: Actual recording requires microphone permission and real device
        // This test only verifies the state management logic
    }
    
    func testPlaybackStateChanges() {
        XCTAssertFalse(audioService.isPlaying, "Should not be playing initially")
        XCTAssertNil(audioService.currentPlayingScriptId, "Should have no current playing script")
        XCTAssertEqual(audioService.playbackProgress, 0, "Playback progress should be 0")
    }
    
    func testStopPlayback() {
        // Test that stop playback resets all playback states
        audioService.stopPlayback()
        
        XCTAssertFalse(audioService.isPlaying)
        XCTAssertNil(audioService.currentPlayingScriptId)
        XCTAssertEqual(audioService.playbackProgress, 0)
    }
    
    func testRequestMicrophonePermission() {
        let expectation = self.expectation(description: "Permission callback")
        
        audioService.requestMicrophonePermission { granted in
            // In test environment, this will depend on system settings
            // We're just testing that the callback is called
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    func testAudioServiceErrorMessages() {
        XCTAssertEqual(
            AudioServiceError.privacyModeActive.errorDescription,
            "Please connect earphones to play audio"
        )
        XCTAssertEqual(
            AudioServiceError.noRecording.errorDescription,
            "No recording available"
        )
        XCTAssertEqual(
            AudioServiceError.permissionDenied.errorDescription,
            "Microphone permission denied"
        )
    }
    
    func testDeleteRecording() {
        // Test that delete recording clears the audio file path
        testScript.audioFilePath = "/fake/path.m4a"
        audioService.deleteRecording(for: testScript)
        XCTAssertNil(testScript.audioFilePath)
    }
    
    func testPlaybackSpeedSetting() {
        // Test that playback speed can be set
        // This just verifies the method exists and doesn't crash
        audioService.setPlaybackSpeed(1.5)
        audioService.setPlaybackSpeed(0.5)
        audioService.setPlaybackSpeed(2.0)
        // No assertion needed - just ensuring no crash
    }
}