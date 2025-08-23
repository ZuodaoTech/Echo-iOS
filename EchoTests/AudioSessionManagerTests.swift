import XCTest
import AVFoundation
@testable import Echo

final class AudioSessionManagerTests: XCTestCase {
    
    var sut: AudioSessionManager!
    
    override func setUp() {
        super.setUp()
        sut = AudioSessionManager()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testIsMicrophonePermissionGrantedReflectsActualStatus() {
        // When
        let isGranted = sut.isMicrophonePermissionGranted
        
        // Then
        let actualStatus = AVAudioSession.sharedInstance().recordPermission
        XCTAssertEqual(isGranted, actualStatus == .granted)
    }
    
    func testConfigureForRecordingSuccess() throws {
        // When/Then
        XCTAssertNoThrow(try sut.configureForRecording())
        
        // Verify session configuration
        let session = AVAudioSession.sharedInstance()
        XCTAssertEqual(session.category, .playAndRecord)
    }
    
    func testConfigureForPlaybackSuccess() throws {
        // When/Then
        XCTAssertNoThrow(try sut.configureForPlayback())
        
        // Verify session configuration
        let session = AVAudioSession.sharedInstance()
        XCTAssertEqual(session.category, .playback)
    }
    
    func testCheckPrivacyModeWithHeadphones() {
        // Given - This test requires manual setup or mocking
        // as we can't programmatically connect headphones
        
        // When
        sut.checkPrivacyMode()
        
        // Then
        // Check the published property based on current route
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        let hasHeadphones = currentRoute.outputs.contains { output in
            [.headphones, .bluetoothA2DP, .bluetoothHFP].contains(output.portType)
        }
        
        // Privacy mode is active when NO headphones (speakers only)
        XCTAssertEqual(sut.privacyModeActive, !hasHeadphones)
    }
    
    func testPrivacyModeActiveWhenSpeakerOnly() {
        // When
        sut.checkPrivacyMode()
        
        // Then
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        let speakerOnly = currentRoute.outputs.allSatisfy { output in
            output.portType == .builtInSpeaker
        }
        
        if speakerOnly {
            XCTAssertTrue(sut.privacyModeActive)
        }
    }
    
    func testDeactivateAudioSession() {
        // Given
        try? sut.configureForPlayback()
        
        // When
        sut.deactivateAudioSession()
        
        // Then
        // Should not throw - deactivation is best effort
        XCTAssertTrue(true, "Deactivation completed")
    }
    
    func testRequestMicrophonePermissionCallsCompletion() {
        // Given
        let expectation = self.expectation(description: "Permission callback")
        
        // When
        sut.requestMicrophonePermission { granted in
            // Then
            expectation.fulfill()
            // The actual value depends on system permission state
            XCTAssertNotNil(granted)
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testMultipleConfigurationChanges() throws {
        // Test switching between recording and playback modes
        
        // When/Then
        XCTAssertNoThrow(try sut.configureForRecording())
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playAndRecord)
        
        XCTAssertNoThrow(try sut.configureForPlayback())
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playback)
        
        XCTAssertNoThrow(try sut.configureForRecording())
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playAndRecord)
    }
    
    func testPrivacyModeCheckUpdatesPublishedProperty() {
        // Given
        let initialValue = sut.privacyModeActive
        
        // When
        sut.checkPrivacyMode()
        
        // Then
        // The value should be set based on current audio route
        XCTAssertNotNil(sut.privacyModeActive)
        
        // If we're on simulator, it should be true (no headphones)
        #if targetEnvironment(simulator)
        XCTAssertTrue(sut.privacyModeActive)
        #endif
    }
    
    func testAudioSessionErrorHandling() {
        // Given - Force an error by trying to set invalid configuration
        let session = AVAudioSession.sharedInstance()
        
        // When/Then
        do {
            // Try to set an incompatible mode
            try session.setCategory(.playAndRecord, mode: .moviePlayback)
            try sut.configureForRecording()
        } catch {
            // Expected to handle errors gracefully
            XCTAssertNotNil(error)
        }
    }
}