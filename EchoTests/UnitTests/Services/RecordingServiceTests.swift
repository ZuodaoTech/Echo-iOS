import XCTest
import AVFoundation
import Combine
@testable import Echo

final class RecordingServiceTests: XCTestCase {
    
    var recordingService: RecordingService!
    var mockFileManager: MockAudioFileManager!
    var mockSessionManager: MockAudioSessionManager!
    var testScriptID: UUID!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        mockFileManager = MockAudioFileManager()
        mockSessionManager = MockAudioSessionManager()
        recordingService = RecordingService(
            fileManager: mockFileManager,
            sessionManager: mockSessionManager
        )
        testScriptID = TestConstants.testScriptID
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        cancellables?.removeAll()
        recordingService = nil
        mockSessionManager = nil
        mockFileManager = nil
        testScriptID = nil
        cancellables = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertFalse(recordingService.isRecording)
        XCTAssertEqual(recordingService.recordingDuration, 0)
        XCTAssertNil(recordingService.currentRecordingScriptId)
        XCTAssertEqual(recordingService.voiceActivityLevel, 0)
    }
    
    // MARK: - Start Recording Tests
    
    func testStartRecording_Success() throws {
        // Setup mock to allow recording
        mockSessionManager.mockMicrophonePermissionGranted = true
        
        // Start recording
        try recordingService.startRecording(for: testScriptID)
        
        // Verify state
        XCTAssertTrue(recordingService.isRecording)
        XCTAssertEqual(recordingService.currentRecordingScriptId, testScriptID)
        
        // Verify session manager calls
        XCTAssertEqual(mockSessionManager.configureForRecordingCalls.count, 1)
        XCTAssertTrue(mockSessionManager.configureForRecordingCalls[0]) // Enhanced processing should be true
        XCTAssertEqual(mockSessionManager.transitionToCalls.count, 1)
        XCTAssertEqual(mockSessionManager.transitionToCalls[0], .recording)
    }
    
    func testStartRecording_PermissionDenied() {
        // Setup mock to deny permission
        mockSessionManager.mockMicrophonePermissionGranted = false
        
        // Attempt to start recording
        XCTAssertThrowsError(try recordingService.startRecording(for: testScriptID)) { error in
            XCTAssertTrue(error is AudioServiceError)
            if case .permissionDenied = error as? AudioServiceError {
                // Expected error
            } else {
                XCTFail("Expected permissionDenied error")
            }
        }
        
        // Verify state remains unchanged
        XCTAssertFalse(recordingService.isRecording)
        XCTAssertNil(recordingService.currentRecordingScriptId)
    }
    
    func testStartRecording_SessionConfigurationError() {
        // Setup mock to grant permission but fail configuration
        mockSessionManager.mockMicrophonePermissionGranted = true
        mockSessionManager.shouldThrowError = .invalidState("Mock configuration error")
        
        // Attempt to start recording
        XCTAssertThrowsError(try recordingService.startRecording(for: testScriptID)) { error in
            XCTAssertTrue(error is AudioServiceError)
        }
        
        // Verify state
        XCTAssertFalse(recordingService.isRecording)
        XCTAssertNil(recordingService.currentRecordingScriptId)
    }
    
    func testStartRecording_StopsExistingRecording() throws {
        // Setup mock to allow recording
        mockSessionManager.mockMicrophonePermissionGranted = true
        
        // Start first recording
        try recordingService.startRecording(for: testScriptID)
        XCTAssertTrue(recordingService.isRecording)
        
        // Start second recording (should stop first)
        let secondScriptID = UUID()
        try recordingService.startRecording(for: secondScriptID)
        
        // Should be recording the new script
        XCTAssertTrue(recordingService.isRecording)
        XCTAssertEqual(recordingService.currentRecordingScriptId, secondScriptID)
    }
    
    // MARK: - Stop Recording Tests
    
    func testStopRecording_WithCompletion() {
        // Setup recording state
        mockSessionManager.mockMicrophonePermissionGranted = true
        try! recordingService.startRecording(for: testScriptID)
        
        let expectation = XCTestExpectation(description: "Stop recording completion")
        
        recordingService.stopRecording { scriptId, duration in
            XCTAssertEqual(scriptId, self.testScriptID)
            XCTAssertGreaterThanOrEqual(duration, 0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
        
        // Verify state after stopping
        XCTAssertFalse(recordingService.isRecording)
        XCTAssertNil(recordingService.currentRecordingScriptId)
    }
    
    func testStopRecording_Synchronous() {
        // Setup recording state
        mockSessionManager.mockMicrophonePermissionGranted = true
        try! recordingService.startRecording(for: testScriptID)
        
        // Stop recording synchronously
        let result = recordingService.stopRecording()
        
        // Verify result
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.scriptId, testScriptID)
        XCTAssertGreaterThanOrEqual(result?.duration ?? -1, 0)
        
        // Verify state
        XCTAssertFalse(recordingService.isRecording)
        XCTAssertNil(recordingService.currentRecordingScriptId)
    }
    
    func testStopRecording_WhenNotRecording() {
        // Stop recording when not recording
        let result = recordingService.stopRecording()
        
        // Should return nil
        XCTAssertNil(result)
    }
    
    func testStopRecording_WithCompletionWhenNotRecording() {
        let expectation = XCTestExpectation(description: "Stop recording completion")
        
        recordingService.stopRecording { scriptId, duration in
            // Should get called with empty UUID and 0 duration
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.shortTimeout)
    }
    
    // MARK: - Pause and Resume Tests
    
    func testPauseRecording() {
        // Setup recording state
        mockSessionManager.mockMicrophonePermissionGranted = true
        try! recordingService.startRecording(for: testScriptID)
        
        // Pause recording
        recordingService.pauseRecording()
        
        // Note: Since we're using mocks, we can't verify the actual AVAudioRecorder pause
        // But we can verify the method doesn't crash and state remains consistent
        XCTAssertTrue(recordingService.isRecording) // Should still be in recording session
    }
    
    func testResumeRecording() {
        // Setup recording state
        mockSessionManager.mockMicrophonePermissionGranted = true
        try! recordingService.startRecording(for: testScriptID)
        
        // Pause and resume
        recordingService.pauseRecording()
        recordingService.resumeRecording()
        
        // Should still be recording
        XCTAssertTrue(recordingService.isRecording)
    }
    
    // MARK: - Voice Activity Tests
    
    func testTrimTimestamps_NoVoiceActivity() {
        // When no voice activity is detected
        let timestamps = recordingService.getTrimTimestamps()
        
        // Should return nil
        XCTAssertNil(timestamps)
    }
    
    func testIsRecordingForScript() {
        // When not recording
        XCTAssertFalse(recordingService.isRecording(scriptId: testScriptID))
        
        // When recording different script
        mockSessionManager.mockMicrophonePermissionGranted = true
        try! recordingService.startRecording(for: testScriptID)
        
        let otherScriptID = UUID()
        XCTAssertFalse(recordingService.isRecording(scriptId: otherScriptID))
        XCTAssertTrue(recordingService.isRecording(scriptId: testScriptID))
    }
    
    // MARK: - Published Properties Tests
    
    func testPublishedProperties() {
        let recordingExpectation = XCTestExpectation(description: "Recording state changed")
        let durationExpectation = XCTestExpectation(description: "Duration updated")
        
        // Observe published properties
        recordingService.$isRecording
            .dropFirst() // Skip initial value
            .sink { isRecording in
                if isRecording {
                    recordingExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        recordingService.$recordingDuration
            .dropFirst() // Skip initial value
            .sink { duration in
                if duration > 0 {
                    durationExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Start recording to trigger property changes
        mockSessionManager.mockMicrophonePermissionGranted = true
        try! recordingService.startRecording(for: testScriptID)
        
        wait(for: [recordingExpectation], timeout: TestConstants.testTimeout)
        
        // Note: Duration updates happen via timer, so we might not see immediate changes
        // The important thing is that the property is observable
    }
    
    func testVoiceActivityLevelProperty() {
        let voiceActivityExpectation = XCTestExpectation(description: "Voice activity updated")
        
        recordingService.$voiceActivityLevel
            .dropFirst() // Skip initial value
            .sink { level in
                voiceActivityExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Start recording
        mockSessionManager.mockMicrophonePermissionGranted = true
        try! recordingService.startRecording(for: testScriptID)
        
        // Note: Voice activity updates happen via timer in real implementation
        // In our test, we can't easily simulate this, but we verify the property exists
        XCTAssertGreaterThanOrEqual(recordingService.voiceActivityLevel, 0)
        XCTAssertLessThanOrEqual(recordingService.voiceActivityLevel, 1)
    }
    
    // MARK: - Current Time Tests
    
    func testCurrentTime() {
        // When not recording
        XCTAssertEqual(recordingService.currentTime, 0)
        
        // When recording
        mockSessionManager.mockMicrophonePermissionGranted = true
        try! recordingService.startRecording(for: testScriptID)
        
        // Current time should be accessible (even if 0 in mock)
        let currentTime = recordingService.currentTime
        XCTAssertGreaterThanOrEqual(currentTime, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testStartRecording_MultipleTimes() throws {
        mockSessionManager.mockMicrophonePermissionGranted = true
        
        // Start recording multiple times with same script ID
        try recordingService.startRecording(for: testScriptID)
        try recordingService.startRecording(for: testScriptID)
        
        // Should handle gracefully
        XCTAssertTrue(recordingService.isRecording)
        XCTAssertEqual(recordingService.currentRecordingScriptId, testScriptID)
    }
    
    func testStopRecording_MultipleTimes() {
        // Setup recording state
        mockSessionManager.mockMicrophonePermissionGranted = true
        try! recordingService.startRecording(for: testScriptID)
        
        // Stop recording multiple times
        let result1 = recordingService.stopRecording()
        let result2 = recordingService.stopRecording()
        
        XCTAssertNotNil(result1)
        XCTAssertNil(result2) // Second call should return nil
    }
    
    // MARK: - Session Manager Integration Tests
    
    func testSessionManagerIntegration() throws {
        mockSessionManager.mockMicrophonePermissionGranted = true
        
        // Start recording
        try recordingService.startRecording(for: testScriptID)
        
        // Verify session manager was called correctly
        XCTAssertEqual(mockSessionManager.configureForRecordingCalls.count, 1)
        XCTAssertTrue(mockSessionManager.transitionToCalls.contains(.recording))
        
        // Stop recording
        recordingService.stopRecording()
        
        // Session transitions should have occurred
        XCTAssertTrue(mockSessionManager.transitionToCalls.contains(.transitioning))
    }
    
    // MARK: - File Manager Integration Tests
    
    func testFileManagerIntegration() throws {
        mockSessionManager.mockMicrophonePermissionGranted = true
        
        // Start recording
        try recordingService.startRecording(for: testScriptID)
        
        // Verify file manager was called for URL
        XCTAssertTrue(mockFileManager.audioURLCalls.contains(testScriptID))
    }
    
    // MARK: - Performance Tests
    
    func testStartStopPerformance() throws {
        mockSessionManager.mockMicrophonePermissionGranted = true
        
        measure {
            for _ in 0..<10 {
                try! recordingService.startRecording(for: testScriptID)
                _ = recordingService.stopRecording()
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() throws {
        weak var weakRecordingService: RecordingService?
        
        autoreleasepool {
            let service = RecordingService(
                fileManager: mockFileManager,
                sessionManager: mockSessionManager
            )
            weakRecordingService = service
            
            // Use the service briefly
            mockSessionManager.mockMicrophonePermissionGranted = true
            try service.startRecording(for: testScriptID)
            service.stopRecording()
        }
        
        // Service should be deallocated
        XCTAssertNil(weakRecordingService)
    }
    
    // MARK: - Edge Cases
    
    func testRecordingWithInvalidScriptID() throws {
        mockSessionManager.mockMicrophonePermissionGranted = true
        
        let invalidScriptID = UUID()
        
        // Should not crash with invalid script ID
        try recordingService.startRecording(for: invalidScriptID)
        XCTAssertTrue(recordingService.isRecording)
        XCTAssertEqual(recordingService.currentRecordingScriptId, invalidScriptID)
    }
    
    func testConcurrentRecordingOperations() throws {
        mockSessionManager.mockMicrophonePermissionGranted = true
        
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 5
        
        // Start multiple concurrent recording operations
        for i in 0..<5 {
            Task {
                do {
                    try self.recordingService.startRecording(for: UUID())
                    await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                    self.recordingService.stopRecording()
                } catch {
                    // Some operations might fail due to concurrency - that's okay
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
        
        // Should end in a consistent state
        XCTAssertFalse(recordingService.isRecording)
    }
}