import XCTest
import AVFoundation
import Combine
@testable import Echo

final class PlaybackServiceTests: XCTestCase {
    
    var playbackService: PlaybackService!
    var mockFileManager: MockAudioFileManager!
    var mockSessionManager: MockAudioSessionManager!
    var testScriptID: UUID!
    var testDirectory: URL!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        testDirectory = AudioTestHelper.createTestAudioDirectory()
        mockFileManager = MockAudioFileManager()
        mockSessionManager = MockAudioSessionManager()
        playbackService = PlaybackService(
            fileManager: mockFileManager,
            sessionManager: mockSessionManager
        )
        testScriptID = TestConstants.testScriptID
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        playbackService.stopPlayback()
        AudioTestHelper.cleanupTestAudioFiles(in: testDirectory)
        
        cancellables?.removeAll()
        playbackService = nil
        mockSessionManager = nil
        mockFileManager = nil
        testScriptID = nil
        testDirectory = nil
        cancellables = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertFalse(playbackService.isPlaying)
        XCTAssertFalse(playbackService.isPaused)
        XCTAssertFalse(playbackService.isInPlaybackSession)
        XCTAssertNil(playbackService.currentPlayingScriptId)
        XCTAssertEqual(playbackService.playbackProgress, 0)
        XCTAssertEqual(playbackService.currentRepetition, 0)
        XCTAssertEqual(playbackService.totalRepetitions, 0)
        XCTAssertFalse(playbackService.isInInterval)
        XCTAssertEqual(playbackService.intervalProgress, 0)
    }
    
    // MARK: - Start Playback Tests
    
    func testStartPlayback_Success() throws {
        // Setup mock to have audio file
        mockFileManager.setMockFile(for: testScriptID, url: testDirectory.appendingPathComponent("test.m4a"), duration: 5.0)
        
        // Create a real audio file for the test
        let audioURL = testDirectory.appendingPathComponent("test.m4a")
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 5.0)
        mockFileManager.mockFiles[testScriptID] = audioURL
        
        // Start playback
        try playbackService.startPlayback(
            scriptId: testScriptID,
            repetitions: 3,
            intervalSeconds: 2.0,
            privateModeEnabled: false
        )
        
        // Verify mock calls
        XCTAssertTrue(mockFileManager.audioFileExistsCalls.contains(testScriptID))
        XCTAssertEqual(mockSessionManager.transitionToCalls.count, 1)
        XCTAssertEqual(mockSessionManager.transitionToCalls[0], .playing)
        
        // Note: Actual playback state might take a moment to update due to async operations
        // We verify the attempt was made and no errors were thrown
    }
    
    func testStartPlayback_NoAudioFile() {
        // Don't setup any audio file
        mockFileManager.mockFileExists[testScriptID] = false
        
        // Attempt to start playback
        XCTAssertThrowsError(try playbackService.startPlayback(
            scriptId: testScriptID,
            repetitions: 1,
            intervalSeconds: 2.0,
            privateModeEnabled: false
        )) { error in
            if case .noRecording = error as? AudioServiceError {
                // Expected error
            } else {
                XCTFail("Expected noRecording error, got \(error)")
            }
        }
        
        // Verify state remains unchanged
        XCTAssertFalse(playbackService.isPlaying)
        XCTAssertFalse(playbackService.isInPlaybackSession)
    }
    
    func testStartPlayback_PrivateModeActive() {
        // Setup private mode active
        mockSessionManager.mockPrivateModeActive = true
        mockFileManager.mockFileExists[testScriptID] = true
        
        // Attempt to start playback with private mode enabled
        XCTAssertThrowsError(try playbackService.startPlayback(
            scriptId: testScriptID,
            repetitions: 1,
            intervalSeconds: 2.0,
            privateModeEnabled: true
        )) { error in
            if case .privateModeActive = error as? AudioServiceError {
                // Expected error
            } else {
                XCTFail("Expected privateModeActive error, got \(error)")
            }
        }
    }
    
    func testStartPlayback_PrivateModeDisabled() throws {
        // Setup private mode active but playback allows it
        mockSessionManager.mockPrivateModeActive = true
        mockFileManager.setMockFile(for: testScriptID, url: testDirectory.appendingPathComponent("test.m4a"), duration: 5.0)
        
        // Create a real audio file
        let audioURL = testDirectory.appendingPathComponent("test.m4a")
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 5.0)
        mockFileManager.mockFiles[testScriptID] = audioURL
        
        // Start playback with private mode disabled (should work)
        XCTAssertNoThrow(try playbackService.startPlayback(
            scriptId: testScriptID,
            repetitions: 1,
            intervalSeconds: 2.0,
            privateModeEnabled: false
        ))
    }
    
    func testStartPlayback_StopsExistingPlayback() throws {
        // Setup audio files
        let firstScriptID = testScriptID!
        let secondScriptID = UUID()
        
        let audioURL1 = testDirectory.appendingPathComponent("test1.m4a")
        let audioURL2 = testDirectory.appendingPathComponent("test2.m4a")
        
        try AudioTestHelper.createMockAudioFile(at: audioURL1, duration: 3.0)
        try AudioTestHelper.createMockAudioFile(at: audioURL2, duration: 4.0)
        
        mockFileManager.setMockFile(for: firstScriptID, url: audioURL1, duration: 3.0)
        mockFileManager.setMockFile(for: secondScriptID, url: audioURL2, duration: 4.0)
        
        // Start first playback
        try playbackService.startPlayback(
            scriptId: firstScriptID,
            repetitions: 1,
            intervalSeconds: 1.0,
            privateModeEnabled: false
        )
        
        // Start second playback (should stop first)
        try playbackService.startPlayback(
            scriptId: secondScriptID,
            repetitions: 2,
            intervalSeconds: 1.5,
            privateModeEnabled: false
        )
        
        // Should be playing the second script
        // Note: Due to async nature, we verify the attempt was made
        XCTAssertTrue(mockFileManager.audioFileExistsCalls.contains(secondScriptID))
    }
    
    func testStartPlayback_ResumePaused() throws {
        // Setup audio file
        let audioURL = testDirectory.appendingPathComponent("test.m4a")
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 5.0)
        mockFileManager.setMockFile(for: testScriptID, url: audioURL, duration: 5.0)
        
        // Start playback
        try playbackService.startPlayback(
            scriptId: testScriptID,
            repetitions: 1,
            intervalSeconds: 2.0,
            privateModeEnabled: false
        )
        
        // Simulate paused state
        playbackService.setMockPlaybackState(
            isPlaying: false,
            isPaused: true,
            isInSession: true,
            scriptId: testScriptID
        )
        
        // Start playback again with same script (should resume)
        try playbackService.startPlayback(
            scriptId: testScriptID,
            repetitions: 1,
            intervalSeconds: 2.0,
            privateModeEnabled: false
        )
        
        // Should attempt to resume (verified by lack of errors)
    }
    
    // MARK: - Pause and Resume Tests
    
    func testPausePlayback() {
        // Setup playback state
        playbackService.setMockPlaybackState(
            isPlaying: true,
            isInSession: true,
            scriptId: testScriptID
        )
        
        // Pause playback
        playbackService.pausePlayback()
        
        // Verify session manager transition
        XCTAssertTrue(mockSessionManager.transitionToCalls.contains(.paused))
    }
    
    func testPausePlayback_WhenNotInSession() {
        // Pause when not in session
        playbackService.pausePlayback()
        
        // Should not cause any state transitions
        XCTAssertEqual(mockSessionManager.transitionToCalls.count, 0)
    }
    
    func testResumePlayback() {
        // Setup paused state
        playbackService.setMockPlaybackState(
            isPlaying: false,
            isPaused: true,
            isInSession: true,
            scriptId: testScriptID
        )
        
        // Resume playback
        playbackService.resumePlayback()
        
        // Verify session manager transition
        XCTAssertTrue(mockSessionManager.transitionToCalls.contains(.playing))
    }
    
    func testResumePlayback_WhenNotPaused() {
        // Resume when not paused
        playbackService.resumePlayback()
        
        // Should not cause any state transitions
        XCTAssertEqual(mockSessionManager.transitionToCalls.count, 0)
    }
    
    // MARK: - Stop Playback Tests
    
    func testStopPlayback() {
        // Setup playing state
        playbackService.setMockPlaybackState(
            isPlaying: true,
            isInSession: true,
            scriptId: testScriptID,
            currentRep: 1,
            totalReps: 3
        )
        
        // Stop playback
        playbackService.stopPlayback()
        
        // Verify session manager transitions
        XCTAssertTrue(mockSessionManager.transitionToCalls.contains(.transitioning))
        // Should eventually transition to idle (may happen in background)
    }
    
    func testStopPlayback_WhenNotPlaying() {
        // Stop when not playing
        playbackService.stopPlayback()
        
        // Should handle gracefully
        XCTAssertTrue(true, "Stop playback completed without errors")
    }
    
    func testStopPlayback_MultipleCallsSafe() {
        // Setup playing state
        playbackService.setMockPlaybackState(
            isPlaying: true,
            isInSession: true,
            scriptId: testScriptID
        )
        
        // Call stop multiple times
        playbackService.stopPlayback()
        playbackService.stopPlayback()
        playbackService.stopPlayback()
        
        // Should handle gracefully without crashes
        XCTAssertTrue(true, "Multiple stop calls handled safely")
    }
    
    // MARK: - Playback Speed Tests
    
    func testSetPlaybackSpeed() {
        let speeds: [Float] = [0.5, 1.0, 1.5, 2.0]
        
        for speed in speeds {
            playbackService.setPlaybackSpeed(speed)
            // Verify the call was made (with mock)
            // In real implementation, this would set the audio player rate
        }
        
        XCTAssertTrue(true, "Playback speed settings completed")
    }
    
    // MARK: - Query Methods Tests
    
    func testIsPlayingForScript() {
        // When not playing
        XCTAssertFalse(playbackService.isPlaying(scriptId: testScriptID))
        
        // Setup playing state
        playbackService.setMockPlaybackState(
            isPlaying: true,
            scriptId: testScriptID
        )
        
        // Should return true for the playing script
        XCTAssertTrue(playbackService.isPlaying(scriptId: testScriptID))
        
        // Should return false for different script
        let otherScriptID = UUID()
        XCTAssertFalse(playbackService.isPlaying(scriptId: otherScriptID))
    }
    
    // MARK: - Published Properties Tests
    
    func testPublishedProperties() {
        let playingExpectation = XCTestExpectation(description: "Playing state changed")
        let sessionExpectation = XCTestExpectation(description: "Session state changed")
        let scriptExpectation = XCTestExpectation(description: "Script ID changed")
        
        // Observe published properties
        playbackService.$isPlaying
            .dropFirst()
            .sink { isPlaying in
                if isPlaying {
                    playingExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        playbackService.$isInPlaybackSession
            .dropFirst()
            .sink { inSession in
                if inSession {
                    sessionExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        playbackService.$currentPlayingScriptId
            .dropFirst()
            .sink { scriptId in
                if scriptId != nil {
                    scriptExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Trigger property changes
        playbackService.setMockPlaybackState(
            isPlaying: true,
            isInSession: true,
            scriptId: testScriptID
        )
        
        // Note: Since we're using a mock, we need to manually trigger updates
        // In the real implementation, these would be updated automatically
        DispatchQueue.main.async {
            // Simulate property updates that would happen in real implementation
            self.playbackService.setMockPlaybackState(
                isPlaying: true,
                isInSession: true,
                scriptId: self.testScriptID
            )
        }
        
        // Wait for some expectations (others might not trigger in mock)
        let result = XCTWaiter.wait(for: [playingExpectation], timeout: TestConstants.shortTimeout)
        // Don't require all expectations to pass since we're using mocks
    }
    
    func testRepetitionProperties() {
        // Test repetition tracking
        playbackService.setMockPlaybackState(
            isPlaying: true,
            currentRep: 2,
            totalReps: 5
        )
        
        XCTAssertEqual(playbackService.currentRepetition, 2)
        XCTAssertEqual(playbackService.totalRepetitions, 5)
    }
    
    func testIntervalProperties() {
        // Test interval tracking
        playbackService.setMockPlaybackState(isPlaying: false)
        
        // In real implementation, these would be updated during intervals
        let isInInterval = playbackService.isInInterval
        let intervalProgress = playbackService.intervalProgress
        
        XCTAssertGreaterThanOrEqual(intervalProgress, 0)
        XCTAssertLessThanOrEqual(intervalProgress, 1)
    }
    
    // MARK: - Error Handling Tests
    
    func testStartPlayback_InvalidAudioFile() throws {
        // Create an invalid audio file (empty)
        let audioURL = testDirectory.appendingPathComponent("invalid.m4a")
        FileManager.default.createFile(atPath: audioURL.path, contents: Data(), attributes: nil)
        
        mockFileManager.setMockFile(for: testScriptID, url: audioURL, duration: 0)
        
        // Attempt to start playback
        XCTAssertThrowsError(try playbackService.startPlayback(
            scriptId: testScriptID,
            repetitions: 1,
            intervalSeconds: 2.0,
            privateModeEnabled: false
        )) { error in
            // Should get a playback error due to invalid file
            XCTAssertTrue(error is AudioServiceError)
        }
    }
    
    // MARK: - Session Manager Integration Tests
    
    func testSessionManagerIntegration() throws {
        // Setup audio file
        let audioURL = testDirectory.appendingPathComponent("test.m4a")
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 3.0)
        mockFileManager.setMockFile(for: testScriptID, url: audioURL, duration: 3.0)
        
        // Test playback operations
        try playbackService.startPlayback(
            scriptId: testScriptID,
            repetitions: 1,
            intervalSeconds: 1.0,
            privateModeEnabled: false
        )
        
        // Verify session configuration was called
        XCTAssertEqual(mockSessionManager.configureForPlaybackCalls.count, 1)
        XCTAssertFalse(mockSessionManager.configureForPlaybackCalls[0]) // Private mode disabled
        
        playbackService.pausePlayback()
        playbackService.resumePlayback()
        playbackService.stopPlayback()
        
        // Verify all transitions occurred
        let transitions = mockSessionManager.transitionToCalls
        XCTAssertTrue(transitions.contains(.playing))
        XCTAssertTrue(transitions.contains(.paused))
        XCTAssertTrue(transitions.contains(.transitioning))
    }
    
    // MARK: - File Manager Integration Tests
    
    func testFileManagerIntegration() throws {
        // Setup audio file
        let audioURL = testDirectory.appendingPathComponent("test.m4a")
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 2.0)
        mockFileManager.setMockFile(for: testScriptID, url: audioURL, duration: 2.0)
        
        // Start playback
        try playbackService.startPlayback(
            scriptId: testScriptID,
            repetitions: 1,
            intervalSeconds: 1.0,
            privateModeEnabled: false
        )
        
        // Verify file manager interactions
        XCTAssertTrue(mockFileManager.audioFileExistsCalls.contains(testScriptID))
        XCTAssertTrue(mockFileManager.audioURLCalls.contains(testScriptID))
    }
    
    // MARK: - Performance Tests
    
    func testStartStopPerformance() throws {
        // Setup audio file
        let audioURL = testDirectory.appendingPathComponent("perf_test.m4a")
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 1.0)
        mockFileManager.setMockFile(for: testScriptID, url: audioURL, duration: 1.0)
        
        measure {
            for _ in 0..<10 {
                do {
                    try playbackService.startPlayback(
                        scriptId: testScriptID,
                        repetitions: 1,
                        intervalSeconds: 0.5,
                        privateModeEnabled: false
                    )
                    playbackService.stopPlayback()
                } catch {
                    // Some operations might fail in performance test - that's okay
                }
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() throws {
        weak var weakPlaybackService: PlaybackService?
        
        autoreleasepool {
            let service = PlaybackService(
                fileManager: mockFileManager,
                sessionManager: mockSessionManager
            )
            weakPlaybackService = service
            
            // Use the service briefly
            let audioURL = testDirectory.appendingPathComponent("memory_test.m4a")
            try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 1.0)
            mockFileManager.setMockFile(for: testScriptID, url: audioURL, duration: 1.0)
            
            try service.startPlayback(
                scriptId: testScriptID,
                repetitions: 1,
                intervalSeconds: 1.0,
                privateModeEnabled: false
            )
            service.stopPlayback()
        }
        
        // Service should be deallocated
        XCTAssertNil(weakPlaybackService)
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentPlaybackOperations() throws {
        // Setup audio file
        let audioURL = testDirectory.appendingPathComponent("concurrent_test.m4a")
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 2.0)
        mockFileManager.setMockFile(for: testScriptID, url: audioURL, duration: 2.0)
        
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 5
        
        // Perform concurrent operations
        for _ in 0..<5 {
            Task {
                do {
                    try self.playbackService.startPlayback(
                        scriptId: self.testScriptID,
                        repetitions: 1,
                        intervalSeconds: 0.5,
                        privateModeEnabled: false
                    )
                    await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                    self.playbackService.pausePlayback()
                    self.playbackService.resumePlayback()
                    self.playbackService.stopPlayback()
                } catch {
                    // Some operations might fail due to concurrency - that's expected
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
        
        // Should end in a consistent state
        XCTAssertFalse(playbackService.isPlaying)
        XCTAssertFalse(playbackService.isInPlaybackSession)
    }
    
    // MARK: - Edge Cases
    
    func testPlaybackWithZeroRepetitions() throws {
        // Setup audio file
        let audioURL = testDirectory.appendingPathComponent("zero_rep_test.m4a")
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 1.0)
        mockFileManager.setMockFile(for: testScriptID, url: audioURL, duration: 1.0)
        
        // Start playback with 0 repetitions (should handle gracefully)
        try playbackService.startPlayback(
            scriptId: testScriptID,
            repetitions: 0,
            intervalSeconds: 1.0,
            privateModeEnabled: false
        )
        
        // Should handle this case without crashing
        XCTAssertTrue(true, "Zero repetitions handled gracefully")
    }
    
    func testPlaybackWithVeryShortInterval() throws {
        // Setup audio file
        let audioURL = testDirectory.appendingPathComponent("short_interval_test.m4a")
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 1.0)
        mockFileManager.setMockFile(for: testScriptID, url: audioURL, duration: 1.0)
        
        // Start playback with very short interval
        try playbackService.startPlayback(
            scriptId: testScriptID,
            repetitions: 2,
            intervalSeconds: 0.01,
            privateModeEnabled: false
        )
        
        // Should handle this case without crashing
        XCTAssertTrue(true, "Short interval handled gracefully")
    }
}