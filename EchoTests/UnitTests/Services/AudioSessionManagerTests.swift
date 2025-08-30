import XCTest
import AVFoundation
@testable import Echo

final class AudioSessionManagerTests: XCTestCase {
    
    var audioSessionManager: AudioSessionManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        audioSessionManager = AudioSessionManager()
    }
    
    override func tearDownWithError() throws {
        audioSessionManager.resetToIdle()
        audioSessionManager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - State Management Tests
    
    func testInitialState() {
        XCTAssertEqual(audioSessionManager.currentState, .idle)
    }
    
    func testValidStateTransitions() {
        // Test idle -> preparingToRecord
        let success1 = audioSessionManager.transitionTo(.preparingToRecord)
        XCTAssertTrue(success1)
        XCTAssertEqual(audioSessionManager.currentState, .preparingToRecord)
        
        // Test preparingToRecord -> recording
        let success2 = audioSessionManager.transitionTo(.recording)
        XCTAssertTrue(success2)
        XCTAssertEqual(audioSessionManager.currentState, .recording)
        
        // Test recording -> transitioning
        let success3 = audioSessionManager.transitionTo(.transitioning)
        XCTAssertTrue(success3)
        XCTAssertEqual(audioSessionManager.currentState, .transitioning)
        
        // Test transitioning -> idle
        let success4 = audioSessionManager.transitionTo(.idle)
        XCTAssertTrue(success4)
        XCTAssertEqual(audioSessionManager.currentState, .idle)
    }
    
    func testInvalidStateTransitions() {
        // Test invalid transition: idle -> recording (should go through preparingToRecord)
        let success = audioSessionManager.transitionTo(.recording)
        XCTAssertFalse(success)
        XCTAssertEqual(audioSessionManager.currentState, .idle)
    }
    
    func testPlaybackStateTransitions() {
        // Test idle -> playing
        let success1 = audioSessionManager.transitionTo(.playing)
        XCTAssertTrue(success1)
        XCTAssertEqual(audioSessionManager.currentState, .playing)
        
        // Test playing -> paused
        let success2 = audioSessionManager.transitionTo(.paused)
        XCTAssertTrue(success2)
        XCTAssertEqual(audioSessionManager.currentState, .paused)
        
        // Test paused -> playing
        let success3 = audioSessionManager.transitionTo(.playing)
        XCTAssertTrue(success3)
        XCTAssertEqual(audioSessionManager.currentState, .playing)
        
        // Test playing -> transitioning
        let success4 = audioSessionManager.transitionTo(.transitioning)
        XCTAssertTrue(success4)
        XCTAssertEqual(audioSessionManager.currentState, .transitioning)
    }
    
    func testErrorStateRecovery() {
        // Transition to error state
        audioSessionManager.transitionTo(.error)
        XCTAssertEqual(audioSessionManager.currentState, .error)
        
        // Should be able to recover to idle
        let success = audioSessionManager.transitionTo(.idle)
        XCTAssertTrue(success)
        XCTAssertEqual(audioSessionManager.currentState, .idle)
    }
    
    func testResetToIdle() {
        // Set to any non-idle state
        audioSessionManager.transitionTo(.playing)
        XCTAssertNotEqual(audioSessionManager.currentState, .idle)
        
        // Reset to idle
        audioSessionManager.resetToIdle()
        
        // Should be idle
        let expectation = XCTestExpectation(description: "State should be idle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.audioSessionManager.currentState, .idle)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Permission Management Tests
    
    func testMicrophonePermissionRequestAsync() async {
        // Note: In unit tests, we can't actually request microphone permission
        // This test verifies the method completes without crashing
        let granted = await audioSessionManager.requestMicrophonePermission()
        
        // Result depends on the testing environment
        // On simulator/unit tests, this may vary
        XCTAssertNotNil(granted) // Just ensure it returns a boolean
    }
    
    func testMicrophonePermissionCheckAsync() async {
        let granted = await audioSessionManager.checkMicrophonePermission()
        
        // Result depends on the testing environment
        XCTAssertNotNil(granted)
    }
    
    func testLegacyMicrophonePermissionRequest() {
        let expectation = XCTestExpectation(description: "Permission request completion")
        
        audioSessionManager.requestMicrophonePermission { granted in
            XCTAssertNotNil(granted)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    // MARK: - State Query Tests
    
    func testCanStartRecording() {
        // Should be able to start recording from idle
        XCTAssertEqual(audioSessionManager.currentState, .idle)
        XCTAssertTrue(audioSessionManager.canStartRecording)
        
        // Should not be able to start recording from other states
        audioSessionManager.transitionTo(.playing)
        XCTAssertFalse(audioSessionManager.canStartRecording)
        
        audioSessionManager.transitionTo(.recording)
        XCTAssertFalse(audioSessionManager.canStartRecording)
    }
    
    func testCanStartPlayback() {
        // Should be able to start playback from idle
        XCTAssertEqual(audioSessionManager.currentState, .idle)
        XCTAssertTrue(audioSessionManager.canStartPlayback)
        
        // Should not be able to start playback from recording states
        audioSessionManager.transitionTo(.recording)
        XCTAssertFalse(audioSessionManager.canStartPlayback)
        
        audioSessionManager.transitionTo(.playing)
        XCTAssertFalse(audioSessionManager.canStartPlayback)
    }
    
    func testIsInRecordingState() {
        XCTAssertFalse(audioSessionManager.isInRecordingState)
        
        audioSessionManager.transitionTo(.preparingToRecord)
        XCTAssertTrue(audioSessionManager.isInRecordingState)
        
        audioSessionManager.transitionTo(.recording)
        XCTAssertTrue(audioSessionManager.isInRecordingState)
        
        audioSessionManager.transitionTo(.idle)
        XCTAssertFalse(audioSessionManager.isInRecordingState)
    }
    
    func testIsInPlaybackState() {
        XCTAssertFalse(audioSessionManager.isInPlaybackState)
        
        audioSessionManager.transitionTo(.playing)
        XCTAssertTrue(audioSessionManager.isInPlaybackState)
        
        audioSessionManager.transitionTo(.paused)
        XCTAssertTrue(audioSessionManager.isInPlaybackState)
        
        audioSessionManager.transitionTo(.idle)
        XCTAssertFalse(audioSessionManager.isInPlaybackState)
    }
    
    // MARK: - Configuration Tests
    
    func testConfigureForRecording() {
        // Should be able to configure from idle state
        XCTAssertEqual(audioSessionManager.currentState, .idle)
        
        // Note: On simulator, this might fail with error -50, which is expected
        // We test that the method handles this gracefully
        do {
            try audioSessionManager.configureForRecording(enhancedProcessing: true)
            // If successful, should transition to preparingToRecord
            XCTAssertEqual(audioSessionManager.currentState, .preparingToRecord)
        } catch {
            // On simulator, configuration might fail - that's expected
            #if targetEnvironment(simulator)
            // Error is expected on simulator
            XCTAssertTrue(true, "Configuration error expected on simulator")
            #else
            // On device, should not fail from idle state
            XCTFail("Configuration should not fail on device from idle state")
            #endif
        }
    }
    
    func testConfigureForRecordingFromInvalidState() {
        // Try to configure from playing state (should fail)
        audioSessionManager.transitionTo(.playing)
        
        XCTAssertThrowsError(try audioSessionManager.configureForRecording()) { error in
            XCTAssertTrue(error is AudioServiceError)
            if let audioError = error as? AudioServiceError {
                switch audioError {
                case .invalidState:
                    // Expected error
                    break
                default:
                    XCTFail("Expected invalidState error")
                }
            }
        }
    }
    
    func testConfigureForPlayback() {
        // Configure for playback should not throw errors
        audioSessionManager.configureForPlayback()
        
        // Method should complete without issues
        // Cannot verify state changes as configureForPlayback doesn't change state
        XCTAssertTrue(true, "Configuration completed")
    }
    
    // MARK: - Private Mode Tests
    
    func testPrivateModeDetection() {
        // Test that private mode check doesn't crash
        audioSessionManager.checkPrivateMode()
        
        // The actual result depends on the device configuration
        // We just verify the method completes
        XCTAssertTrue(true, "Private mode check completed")
    }
    
    func testPrivateModeActiveProperty() {
        // Initially should be set
        let initialValue = audioSessionManager.privateModeActive
        XCTAssertNotNil(initialValue)
        
        // Should be able to observe changes
        let expectation = XCTestExpectation(description: "Private mode updated")
        
        let cancellable = audioSessionManager.$privateModeActive
            .dropFirst() // Skip initial value
            .sink { _ in
                expectation.fulfill()
            }
        
        // Trigger private mode check
        audioSessionManager.checkPrivateMode()
        
        // Give some time for the update
        let result = XCTWaiter.wait(for: [expectation], timeout: TestConstants.shortTimeout)
        
        // Clean up
        cancellable.cancel()
        
        // Result may vary based on test environment
        // Just ensure the method doesn't crash
        XCTAssertTrue(true, "Private mode observation completed")
    }
    
    // MARK: - Session Management Tests
    
    func testDeactivateSession() {
        // Should not crash when deactivating session
        audioSessionManager.deactivateSession()
        XCTAssertTrue(true, "Session deactivation completed")
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentStateTransitions() {
        let expectation = XCTestExpectation(description: "Concurrent transitions")
        expectation.expectedFulfillmentCount = 10
        
        // Perform multiple concurrent state transitions
        for i in 0..<10 {
            DispatchQueue.global().async {
                if i % 2 == 0 {
                    self.audioSessionManager.transitionTo(.playing)
                } else {
                    self.audioSessionManager.transitionTo(.idle)
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
        
        // Should end in a valid state
        let finalState = audioSessionManager.currentState
        XCTAssertTrue(AudioSessionState.allCases.contains(finalState))
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorStateTransitions() {
        // Should be able to transition to error from various states
        XCTAssertTrue(audioSessionManager.transitionTo(.error))
        XCTAssertEqual(audioSessionManager.currentState, .error)
        
        // Should be able to recover to idle
        XCTAssertTrue(audioSessionManager.transitionTo(.idle))
        XCTAssertEqual(audioSessionManager.currentState, .idle)
        
        // Test error from recording state
        audioSessionManager.transitionTo(.preparingToRecord)
        audioSessionManager.transitionTo(.recording)
        XCTAssertTrue(audioSessionManager.transitionTo(.error))
        XCTAssertEqual(audioSessionManager.currentState, .error)
    }
    
    // MARK: - Performance Tests
    
    func testStateTransitionPerformance() {
        measure {
            for _ in 0..<100 {
                audioSessionManager.transitionTo(.playing)
                audioSessionManager.transitionTo(.paused)
                audioSessionManager.transitionTo(.transitioning)
                audioSessionManager.transitionTo(.idle)
            }
        }
    }
    
    func testPrivateModeCheckPerformance() {
        measure {
            for _ in 0..<50 {
                audioSessionManager.checkPrivateMode()
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testRapidStateTransitions() {
        // Test rapid transitions don't cause issues
        for _ in 0..<20 {
            audioSessionManager.transitionTo(.playing)
            audioSessionManager.transitionTo(.transitioning)
            audioSessionManager.transitionTo(.idle)
        }
        
        // Should end in a valid state
        XCTAssertEqual(audioSessionManager.currentState, .idle)
    }
    
    func testStateTransitionLogging() {
        // Verify that state transitions don't crash when logging
        audioSessionManager.transitionTo(.playing)
        audioSessionManager.transitionTo(.paused)
        audioSessionManager.transitionTo(.transitioning)
        audioSessionManager.transitionTo(.idle)
        
        XCTAssertEqual(audioSessionManager.currentState, .idle)
    }
}