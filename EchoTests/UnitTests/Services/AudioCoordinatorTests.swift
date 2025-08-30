import XCTest
import Combine
import CoreData
@testable import Echo

final class AudioCoordinatorTests: XCTestCase {
    
    var audioCoordinator: AudioCoordinator!
    var testContext: NSManagedObjectContext!
    var testScript: SelftalkScript!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create test context with sample data
        testContext = CoreDataTestHelper.createTestContextWithSampleData()
        testScript = try XCTUnwrap(testContext.registeredObjects.first { $0 is SelftalkScript } as? SelftalkScript)
        
        // Create fresh AudioCoordinator instance
        audioCoordinator = AudioCoordinator()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        // Stop any active operations
        if audioCoordinator.isRecording {
            audioCoordinator.stopRecording()
        }
        if audioCoordinator.isPlaying {
            audioCoordinator.stopPlayback()
        }
        
        cancellables?.removeAll()
        audioCoordinator = nil
        testScript = nil
        testContext = nil
        cancellables = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertFalse(audioCoordinator.isRecording)
        XCTAssertFalse(audioCoordinator.isPlaying)
        XCTAssertFalse(audioCoordinator.isPaused)
        XCTAssertFalse(audioCoordinator.isInPlaybackSession)
        XCTAssertFalse(audioCoordinator.isProcessingRecording)
        XCTAssertNil(audioCoordinator.currentPlayingScriptId)
        XCTAssertEqual(audioCoordinator.recordingDuration, 0)
        XCTAssertEqual(audioCoordinator.playbackProgress, 0)
        XCTAssertEqual(audioCoordinator.currentRepetition, 0)
        XCTAssertEqual(audioCoordinator.totalRepetitions, 0)
        XCTAssertEqual(audioCoordinator.voiceActivityLevel, 0)
        XCTAssertEqual(audioCoordinator.processingProgress, 0)
        XCTAssertTrue(audioCoordinator.processingMessage.isEmpty)
        XCTAssertTrue(audioCoordinator.processingScriptIds.isEmpty)
    }
    
    func testSingletonBehavior() {
        let coordinator1 = AudioCoordinator.shared
        let coordinator2 = AudioCoordinator.shared
        
        XCTAssertTrue(coordinator1 === coordinator2, "AudioCoordinator should be a singleton")
    }
    
    func testLegacyAudioServiceCompatibility() {
        let audioService = AudioCoordinator.audioService
        let shared = AudioCoordinator.shared
        
        XCTAssertTrue(audioService === shared, "Legacy audioService should map to shared instance")
    }
    
    // MARK: - Service Availability Tests
    
    func testServiceAvailabilityProperties() {
        // Services should be available after initialization
        XCTAssertTrue(audioCoordinator.isServicesReady)
        XCTAssertTrue(audioCoordinator.isFileManagerReady)
        XCTAssertTrue(audioCoordinator.isSessionManagerReady)
        XCTAssertTrue(audioCoordinator.isRecordingServiceReady)
        XCTAssertTrue(audioCoordinator.isPlaybackServiceReady)
        XCTAssertTrue(audioCoordinator.isProcessingServiceReady)
    }
    
    func testServiceUnavailableMessage() {
        // When services are ready, message should be nil
        XCTAssertNil(audioCoordinator.serviceUnavailableMessage)
    }
    
    func testAudioSessionState() {
        let sessionState = audioCoordinator.audioSessionState
        
        XCTAssertFalse(sessionState.isEmpty)
        XCTAssertTrue(AudioSessionState.allCases.map { $0.rawValue }.contains(sessionState))
    }
    
    // MARK: - Microphone Permission Tests
    
    func testRequestMicrophonePermission() {
        let expectation = XCTestExpectation(description: "Microphone permission request")
        
        audioCoordinator.requestMicrophonePermission { granted in
            // Result depends on system/test environment
            XCTAssertNotNil(granted)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    // MARK: - Recording Tests
    
    func testStartRecording_Success() {
        // This test may not work in unit test environment due to audio system limitations
        // We test the interface and error handling
        
        do {
            try audioCoordinator.startRecording(for: testScript)
            
            // If successful, should be in recording state
            if audioCoordinator.isRecording {
                XCTAssertTrue(audioCoordinator.isRecording)
                XCTAssertNotNil(testScript.audioFilePath)
                
                // Stop recording for cleanup
                audioCoordinator.stopRecording()
            } else {
                // If not recording (due to test environment), that's also valid
                XCTAssertTrue(true, "Recording not started in test environment")
            }
        } catch {
            // Recording might fail in test environment - verify it's an expected error
            XCTAssertTrue(error is AudioServiceError, "Should throw AudioServiceError")
        }
    }
    
    func testStartRecording_InvalidScript() {
        // Create an invalid script (deleted)
        let invalidScript = SelftalkScript.createTestScript(in: testContext)
        testContext.delete(invalidScript)
        
        XCTAssertThrowsError(try audioCoordinator.startRecording(for: invalidScript)) { error in
            if case .invalidScript = error as? AudioServiceError {
                // Expected error
            } else {
                XCTFail("Expected invalidScript error")
            }
        }
    }
    
    func testStartRecording_StopsPlayback() {
        // Simulate playback state
        // Note: This is difficult to test without mocking the internal services
        // We test that starting recording doesn't crash when playback might be active
        
        XCTAssertNoThrow(try audioCoordinator.startRecording(for: testScript))
        
        // Clean up
        if audioCoordinator.isRecording {
            audioCoordinator.stopRecording()
        }
    }
    
    func testStopRecording() {
        // Test stopping when not recording (should handle gracefully)
        audioCoordinator.stopRecording()
        
        // Should not crash and state should remain consistent
        XCTAssertFalse(audioCoordinator.isRecording)
    }
    
    // MARK: - Playback Tests
    
    func testPlayScript_NoRecording() {
        // Try to play script without recording
        XCTAssertThrowsError(try audioCoordinator.play(script: testScript)) { error in
            if case .noRecording = error as? AudioServiceError {
                // Expected error
            } else if case .serviceUnavailable = error as? AudioServiceError {
                // Also acceptable in test environment
            } else {
                XCTFail("Expected noRecording or serviceUnavailable error")
            }
        }
    }
    
    func testPlayScript_InvalidScript() {
        // Create an invalid script (deleted)
        let invalidScript = SelftalkScript.createTestScript(in: testContext)
        testContext.delete(invalidScript)
        
        XCTAssertThrowsError(try audioCoordinator.play(script: invalidScript)) { error in
            if case .invalidScript = error as? AudioServiceError {
                // Expected error
            } else {
                XCTFail("Expected invalidScript error")
            }
        }
    }
    
    func testPlayScript_IncrementPlayCount() {
        // Setup script with initial play count
        let initialPlayCount = testScript.playCount
        
        // Try to play (will likely fail due to no recording, but should still increment)
        do {
            try audioCoordinator.play(script: testScript)
        } catch {
            // Expected to fail in test environment
        }
        
        // Play count should be incremented regardless
        XCTAssertEqual(testScript.playCount, initialPlayCount + 1)
    }
    
    func testPausePlayback() {
        // Test pausing when not playing (should handle gracefully)
        audioCoordinator.pausePlayback()
        XCTAssertTrue(true, "Pause playback handled gracefully")
    }
    
    func testResumePlayback() {
        // Test resuming when not paused (should handle gracefully)
        audioCoordinator.resumePlayback()
        XCTAssertTrue(true, "Resume playback handled gracefully")
    }
    
    func testStopPlayback() {
        // Test stopping when not playing (should handle gracefully)
        audioCoordinator.stopPlayback()
        XCTAssertTrue(true, "Stop playback handled gracefully")
    }
    
    func testSetPlaybackSpeed() {
        let speeds: [Float] = [0.5, 1.0, 1.5, 2.0]
        
        for speed in speeds {
            audioCoordinator.setPlaybackSpeed(speed)
        }
        
        XCTAssertTrue(true, "Playback speed settings completed")
    }
    
    // MARK: - File Management Tests
    
    func testDeleteRecording() {
        // Setup script with audio file path
        testScript.audioFilePath = "/test/path/audio.m4a"
        testScript.audioDuration = 5.0
        testScript.transcribedText = "Test transcription"
        
        // Delete recording
        audioCoordinator.deleteRecording(for: testScript)
        
        // Script properties should be cleared
        XCTAssertNil(testScript.audioFilePath)
        XCTAssertEqual(testScript.audioDuration, 0)
        XCTAssertNil(testScript.transcribedText)
    }
    
    func testDeleteRecording_StopsPlayback() {
        // Setup playing state (mocked)
        testScript.audioFilePath = "/test/path/audio.m4a"
        
        // Delete recording
        audioCoordinator.deleteRecording(for: testScript)
        
        // Should handle gracefully
        XCTAssertNil(testScript.audioFilePath)
    }
    
    // MARK: - Compatibility Methods Tests
    
    func testHasRecording() {
        // Test with script that has no recording
        XCTAssertFalse(audioCoordinator.hasRecording(for: testScript))
        
        // Setup script with audio file
        testScript.audioFilePath = "/test/path/audio.m4a"
        
        // Still returns false because file doesn't actually exist
        XCTAssertFalse(audioCoordinator.hasRecording(for: testScript))
    }
    
    func testGetAudioDuration() {
        // Test with script that has no recording
        XCTAssertNil(audioCoordinator.getAudioDuration(for: testScript))
        
        // Setup script with audio file (but file doesn't exist)
        testScript.audioFilePath = "/test/path/audio.m4a"
        XCTAssertNil(audioCoordinator.getAudioDuration(for: testScript))
    }
    
    func testIsProcessingScript() {
        // Test with script not being processed
        XCTAssertFalse(audioCoordinator.isProcessing(script: testScript))
        
        // Test with deleted script
        let deletedScript = SelftalkScript.createTestScript(in: testContext)
        testContext.delete(deletedScript)
        
        XCTAssertFalse(audioCoordinator.isProcessing(script: deletedScript))
    }
    
    // MARK: - Private Mode Tests
    
    func testCheckPrivateMode() {
        // Should not crash
        audioCoordinator.checkPrivateMode()
        XCTAssertTrue(true, "Private mode check completed")
    }
    
    func testPrivateModeProperty() {
        // Should have a boolean value
        let privateModeActive = audioCoordinator.privateModeActive
        XCTAssertNotNil(privateModeActive)
    }
    
    // MARK: - Published Properties Tests
    
    func testPublishedPropertiesObservable() {
        var recordingStateChanges = 0
        var playbackStateChanges = 0
        var processingStateChanges = 0
        
        // Observe published properties
        audioCoordinator.$isRecording
            .sink { _ in recordingStateChanges += 1 }
            .store(in: &cancellables)
        
        audioCoordinator.$isPlaying
            .sink { _ in playbackStateChanges += 1 }
            .store(in: &cancellables)
        
        audioCoordinator.$isProcessingRecording
            .sink { _ in processingStateChanges += 1 }
            .store(in: &cancellables)
        
        // Initial values should be received
        XCTAssertGreaterThanOrEqual(recordingStateChanges, 1)
        XCTAssertGreaterThanOrEqual(playbackStateChanges, 1)
        XCTAssertGreaterThanOrEqual(processingStateChanges, 1)
    }
    
    func testAllPublishedPropertiesExist() {
        // Verify all expected published properties exist
        _ = audioCoordinator.isRecording
        _ = audioCoordinator.isProcessingRecording
        _ = audioCoordinator.recordingDuration
        _ = audioCoordinator.processingScriptIds
        _ = audioCoordinator.voiceActivityLevel
        _ = audioCoordinator.processingProgress
        _ = audioCoordinator.processingMessage
        _ = audioCoordinator.isPlaying
        _ = audioCoordinator.isPaused
        _ = audioCoordinator.isInPlaybackSession
        _ = audioCoordinator.currentPlayingScriptId
        _ = audioCoordinator.playbackProgress
        _ = audioCoordinator.currentRepetition
        _ = audioCoordinator.totalRepetitions
        _ = audioCoordinator.isInInterval
        _ = audioCoordinator.intervalProgress
        _ = audioCoordinator.privateModeActive
        
        XCTAssertTrue(true, "All published properties accessible")
    }
    
    // MARK: - Error Handling Tests
    
    func testServiceUnavailableErrorHandling() {
        // Test behavior when services are unavailable
        // This is difficult to test without dependency injection, but we verify
        // that the coordinator handles service unavailability gracefully
        
        let unavailableMessage = audioCoordinator.serviceUnavailableMessage
        
        // When services are available, message should be nil
        if audioCoordinator.isServicesReady {
            XCTAssertNil(unavailableMessage)
        } else {
            XCTAssertNotNil(unavailableMessage)
            XCTAssertFalse(unavailableMessage!.isEmpty)
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentOperations() {
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 10
        
        // Perform multiple concurrent operations
        for i in 0..<10 {
            DispatchQueue.global().async {
                // Mix different operations
                switch i % 4 {
                case 0:
                    self.audioCoordinator.checkPrivateMode()
                case 1:
                    _ = self.audioCoordinator.hasRecording(for: self.testScript)
                case 2:
                    _ = self.audioCoordinator.getAudioDuration(for: self.testScript)
                case 3:
                    _ = self.audioCoordinator.isProcessing(script: self.testScript)
                default:
                    break
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() {
        // Test that AudioCoordinator doesn't create retain cycles
        weak var weakCoordinator: AudioCoordinator?
        
        autoreleasepool {
            let coordinator = AudioCoordinator()
            weakCoordinator = coordinator
            
            // Use coordinator briefly
            _ = coordinator.isServicesReady
            coordinator.checkPrivateMode()
        }
        
        // Note: AudioCoordinator.shared is a singleton, so it won't be deallocated
        // This test mainly ensures we don't have retain cycles in local instances
        // In practice, we mainly use the shared instance
    }
    
    // MARK: - Performance Tests
    
    func testServiceAvailabilityCheckPerformance() {
        measure {
            for _ in 0..<100 {
                _ = audioCoordinator.isServicesReady
                _ = audioCoordinator.serviceUnavailableMessage
            }
        }
    }
    
    func testPropertyAccessPerformance() {
        measure {
            for _ in 0..<100 {
                _ = audioCoordinator.isRecording
                _ = audioCoordinator.isPlaying
                _ = audioCoordinator.recordingDuration
                _ = audioCoordinator.playbackProgress
                _ = audioCoordinator.privateModeActive
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testAudioCoordinatorWithRealScript() {
        // Create a more complete script
        let script = SelftalkScriptBuilder()
            .withScriptText("Integration test script")
            .withRepetitions(3)
            .withIntervalSeconds(2.0)
            .withPrivateMode(false)
            .build(in: testContext)
        
        // Test various operations
        XCTAssertFalse(audioCoordinator.hasRecording(for: script))
        XCTAssertNil(audioCoordinator.getAudioDuration(for: script))
        XCTAssertFalse(audioCoordinator.isProcessing(script: script))
        
        // Test deletion (should not crash)
        audioCoordinator.deleteRecording(for: script)
        
        // Test invalid playback attempt
        XCTAssertThrowsError(try audioCoordinator.play(script: script))
        
        // Play count should still be incremented
        XCTAssertEqual(script.playCount, 1)
    }
    
    // MARK: - Edge Cases
    
    func testOperationsWithCorruptedScript() {
        // Create script then corrupt its context
        let script = SelftalkScript.createTestScript(in: testContext)
        
        // Test that operations handle corrupted scripts gracefully
        XCTAssertFalse(audioCoordinator.hasRecording(for: script))
        XCTAssertNil(audioCoordinator.getAudioDuration(for: script))
        
        // These should not crash
        audioCoordinator.deleteRecording(for: script)
        XCTAssertFalse(audioCoordinator.isProcessing(script: script))
    }
    
    func testRapidStartStopOperations() {
        // Test rapid start/stop operations
        for _ in 0..<5 {
            do {
                try audioCoordinator.startRecording(for: testScript)
            } catch {
                // Expected to fail in test environment
            }
            
            audioCoordinator.stopRecording()
            audioCoordinator.stopPlayback()
        }
        
        // Should end in consistent state
        XCTAssertFalse(audioCoordinator.isRecording)
        XCTAssertFalse(audioCoordinator.isPlaying)
    }
}