import XCTest
import CoreData
@testable import Pando_Echo

class NoRecordingHandlingTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var testScript: SelftalkScript!
    var audioService: AudioService!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        audioService = AudioService()
        
        // Create a test script without recording
        testScript = SelftalkScript.create(
            scriptText: "Test script without recording",
            category: nil,
            repetitions: 3,
            privacyMode: false,
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
    
    func testScriptWithoutRecordingHasCorrectState() {
        // Script should not have recording initially
        XCTAssertFalse(testScript.hasRecording, "New script should not have recording")
        XCTAssertNil(testScript.audioFilePath, "Audio file path should be nil")
        XCTAssertNil(testScript.audioFileURL, "Audio file URL should be nil")
    }
    
    func testPlayingScriptWithoutRecordingThrowsError() {
        // Attempting to play should throw noRecording error
        XCTAssertThrowsError(try audioService.play(script: testScript)) { error in
            XCTAssertEqual(error as? AudioServiceError, AudioServiceError.noRecording,
                          "Should throw noRecording error when trying to play script without recording")
        }
    }
    
    func testScriptWithRecordingPathHasCorrectState() {
        // Simulate having a recording
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioPath = documentsPath.appendingPathComponent("Recordings")
        let testAudioPath = audioPath.appendingPathComponent("\(testScript.id.uuidString).m4a")
        
        testScript.audioFilePath = testAudioPath.path
        
        XCTAssertTrue(testScript.hasRecording, "Script with audio path should have recording")
        XCTAssertNotNil(testScript.audioFileURL, "Should have valid audio URL")
    }
    
    func testAudioServiceDoesNotPlayWithoutFile() {
        // Set a path but don't create actual file
        testScript.audioFilePath = "/fake/path/audio.m4a"
        
        // Should still throw error because file doesn't exist
        XCTAssertThrowsError(try audioService.play(script: testScript)) { error in
            XCTAssertEqual(error as? AudioServiceError, AudioServiceError.noRecording,
                          "Should throw noRecording error when file doesn't exist")
        }
    }
    
    func testNoRecordingIndicatorShown() {
        // Test that UI would show recording indicator
        XCTAssertFalse(testScript.hasRecording)
        
        // In actual UI, this would trigger showing:
        // - "Tap and hold to record" message
        // - mic.slash icon
        // These are tested visually in ScriptCard
    }
    
    func testFormattedDurationForNoRecording() {
        // Without recording, duration should be 0
        XCTAssertEqual(testScript.audioDuration, 0)
        XCTAssertEqual(testScript.formattedDuration, "0s")
        XCTAssertEqual(testScript.totalDuration, 0)
        XCTAssertEqual(testScript.formattedTotalDuration, "0s")
    }
}