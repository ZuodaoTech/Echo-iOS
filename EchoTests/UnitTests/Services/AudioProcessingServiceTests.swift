import XCTest
import AVFoundation
import Speech
@testable import Echo

final class AudioProcessingServiceTests: XCTestCase {
    
    var audioProcessingService: AudioProcessingService!
    var mockFileManager: MockAudioFileManager!
    var testScriptID: UUID!
    var testDirectory: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        testDirectory = AudioTestHelper.createTestAudioDirectory()
        mockFileManager = MockAudioFileManager()
        audioProcessingService = AudioProcessingService(fileManager: mockFileManager)
        testScriptID = TestConstants.testScriptID
    }
    
    override func tearDownWithError() throws {
        AudioTestHelper.cleanupTestAudioFiles(in: testDirectory)
        
        audioProcessingService = nil
        mockFileManager = nil
        testScriptID = nil
        testDirectory = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(audioProcessingService)
    }
    
    // MARK: - Speech Recognition Status Tests
    
    func testCheckSpeechRecognitionStatus() {
        let status = audioProcessingService.checkSpeechRecognitionStatus()
        
        // Verify structure of response
        XCTAssertNotNil(status.available)
        XCTAssertNotNil(status.onDevice)
        XCTAssertFalse(status.message.isEmpty)
        
        // The actual values depend on system configuration
        // Just verify the method completes and returns expected structure
    }
    
    // MARK: - Audio Processing Tests
    
    func testProcessRecording_WithoutTrimTimestamps() {
        let expectation = XCTestExpectation(description: "Processing completion")
        
        // Setup mock file URLs
        let audioURL = testDirectory.appendingPathComponent("test.m4a")
        let originalURL = testDirectory.appendingPathComponent("test_original.m4a")
        
        mockFileManager.mockFiles[testScriptID] = audioURL
        mockFileManager.mockOriginalFiles[testScriptID] = originalURL
        
        // Create a test audio file
        do {
            try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 3.0)
        } catch {
            XCTFail("Failed to create test audio file: \(error)")
            return
        }
        
        // Process recording
        audioProcessingService.processRecording(for: testScriptID) { success in
            // Processing should complete (success depends on audio content)
            XCTAssertNotNil(success)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    func testProcessRecording_WithTrimTimestamps() {
        let expectation = XCTestExpectation(description: "Processing with timestamps")
        
        // Setup mock file URLs
        let audioURL = testDirectory.appendingPathComponent("trim_test.m4a")
        let originalURL = testDirectory.appendingPathComponent("trim_test_original.m4a")
        
        mockFileManager.mockFiles[testScriptID] = audioURL
        mockFileManager.mockOriginalFiles[testScriptID] = originalURL
        
        // Create test audio file
        do {
            try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 10.0)
        } catch {
            XCTFail("Failed to create test audio file: \(error)")
            return
        }
        
        // Process with trim timestamps
        let trimTimestamps = (start: 1.0, end: 8.0)
        audioProcessingService.processRecording(
            for: testScriptID,
            trimTimestamps: trimTimestamps
        ) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
        
        // Verify original file was saved
        XCTAssertTrue(FileManager.default.fileExists(atPath: originalURL.path))
    }
    
    func testProcessRecording_NonExistentFile() {
        let expectation = XCTestExpectation(description: "Processing nonexistent file")
        
        // Setup URLs for files that don't exist
        let audioURL = testDirectory.appendingPathComponent("nonexistent.m4a")
        mockFileManager.mockFiles[testScriptID] = audioURL
        
        // Process recording
        audioProcessingService.processRecording(for: testScriptID) { success in
            XCTAssertFalse(success)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    func testProcessRecording_VeryShortAudio() {
        let expectation = XCTestExpectation(description: "Processing very short audio")
        
        // Setup mock file URLs
        let audioURL = testDirectory.appendingPathComponent("short.m4a")
        let originalURL = testDirectory.appendingPathComponent("short_original.m4a")
        
        mockFileManager.mockFiles[testScriptID] = audioURL
        mockFileManager.mockOriginalFiles[testScriptID] = originalURL
        
        // Create very short audio file
        do {
            try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 0.2)
        } catch {
            XCTFail("Failed to create short audio file: \(error)")
            return
        }
        
        // Process recording
        audioProcessingService.processRecording(for: testScriptID) { success in
            // Short audio should be processed successfully (no trimming needed)
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    // MARK: - Transcription Tests
    
    func testTranscribeRecording_AuthorizationNotDetermined() {
        let expectation = XCTestExpectation(description: "Transcription with unknown authorization")
        
        // Setup mock file URLs
        let originalURL = testDirectory.appendingPathComponent("transcribe_test_original.m4a")
        mockFileManager.mockOriginalFiles[testScriptID] = originalURL
        
        // Create test audio file
        do {
            try AudioTestHelper.createMockAudioFile(at: originalURL, duration: 2.0)
        } catch {
            XCTFail("Failed to create test audio file: \(error)")
            return
        }
        
        // Attempt transcription (may request authorization)
        audioProcessingService.transcribeRecording(for: testScriptID, languageCode: "en-US") { transcription in
            // Result depends on authorization status
            // Just verify the method completes without crashing
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    func testTranscribeRecording_NonExistentFile() {
        let expectation = XCTestExpectation(description: "Transcription of nonexistent file")
        
        // Setup URL for file that doesn't exist
        let originalURL = testDirectory.appendingPathComponent("nonexistent_original.m4a")
        mockFileManager.mockOriginalFiles[testScriptID] = originalURL
        
        // Attempt transcription
        audioProcessingService.transcribeRecording(for: testScriptID) { transcription in
            XCTAssertNil(transcription)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    func testTranscribeRecording_WithLanguageCode() {
        let expectation = XCTestExpectation(description: "Transcription with language code")
        
        // Setup mock file URLs
        let originalURL = testDirectory.appendingPathComponent("lang_test_original.m4a")
        mockFileManager.mockOriginalFiles[testScriptID] = originalURL
        
        // Create test audio file
        do {
            try AudioTestHelper.createMockAudioFile(at: originalURL, duration: 2.0)
        } catch {
            XCTFail("Failed to create test audio file: \(error)")
            return
        }
        
        // Test various language codes
        let languageCodes = ["en-US", "zh-CN", "ja-JP", "invalid-lang"]
        var completedTests = 0
        let totalTests = languageCodes.count
        
        for languageCode in languageCodes {
            audioProcessingService.transcribeRecording(
                for: testScriptID,
                languageCode: languageCode
            ) { transcription in
                // Result depends on language availability and authorization
                completedTests += 1
                if completedTests == totalTests {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout * 2)
    }
    
    func testTranscribeRecording_DefaultLanguage() {
        let expectation = XCTestExpectation(description: "Transcription with default language")
        
        // Setup mock file URLs
        let originalURL = testDirectory.appendingPathComponent("default_lang_original.m4a")
        mockFileManager.mockOriginalFiles[testScriptID] = originalURL
        
        // Create test audio file
        do {
            try AudioTestHelper.createMockAudioFile(at: originalURL, duration: 1.5)
        } catch {
            XCTFail("Failed to create test audio file: \(error)")
            return
        }
        
        // Transcribe with default language (nil)
        audioProcessingService.transcribeRecording(for: testScriptID, languageCode: nil) { transcription in
            // Should default to en-US and complete
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    // MARK: - File Manager Integration Tests
    
    func testFileManagerIntegration() {
        let expectation = XCTestExpectation(description: "File manager integration")
        
        // Setup mock file URLs
        let audioURL = testDirectory.appendingPathComponent("integration_test.m4a")
        let originalURL = testDirectory.appendingPathComponent("integration_test_original.m4a")
        
        mockFileManager.mockFiles[testScriptID] = audioURL
        mockFileManager.mockOriginalFiles[testScriptID] = originalURL
        
        // Create test audio file
        do {
            try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 2.0)
        } catch {
            XCTFail("Failed to create test audio file: \(error)")
            return
        }
        
        // Process recording
        audioProcessingService.processRecording(for: testScriptID) { success in
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
        
        // Verify file manager was called for URLs
        XCTAssertTrue(mockFileManager.audioURLCalls.contains(testScriptID))
    }
    
    // MARK: - Error Handling Tests
    
    func testProcessRecording_InvalidAudioFile() {
        let expectation = XCTestExpectation(description: "Processing invalid audio file")
        
        // Create an invalid audio file (just empty data)
        let audioURL = testDirectory.appendingPathComponent("invalid.m4a")
        FileManager.default.createFile(atPath: audioURL.path, contents: Data(), attributes: nil)
        
        mockFileManager.mockFiles[testScriptID] = audioURL
        
        // Process recording
        audioProcessingService.processRecording(for: testScriptID) { success in
            XCTAssertFalse(success)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    func testTranscribeRecording_InvalidAudioFile() {
        let expectation = XCTestExpectation(description: "Transcribing invalid audio file")
        
        // Create an invalid audio file
        let originalURL = testDirectory.appendingPathComponent("invalid_original.m4a")
        FileManager.default.createFile(atPath: originalURL.path, contents: Data(), attributes: nil)
        
        mockFileManager.mockOriginalFiles[testScriptID] = originalURL
        
        // Attempt transcription
        audioProcessingService.transcribeRecording(for: testScriptID) { transcription in
            XCTAssertNil(transcription)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    // MARK: - Performance Tests
    
    func testProcessingPerformance() {
        // Setup audio file
        let audioURL = testDirectory.appendingPathComponent("perf_test.m4a")
        let originalURL = testDirectory.appendingPathComponent("perf_test_original.m4a")
        
        mockFileManager.mockFiles[testScriptID] = audioURL
        mockFileManager.mockOriginalFiles[testScriptID] = originalURL
        
        do {
            try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 5.0)
        } catch {
            XCTFail("Failed to create test audio file: \(error)")
            return
        }
        
        measure {
            let expectation = XCTestExpectation(description: "Processing performance")
            
            audioProcessingService.processRecording(for: testScriptID) { _ in
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: TestConstants.testTimeout)
        }
    }
    
    func testSpeechRecognitionStatusPerformance() {
        measure {
            for _ in 0..<10 {
                _ = audioProcessingService.checkSpeechRecognitionStatus()
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() {
        weak var weakProcessingService: AudioProcessingService?
        
        autoreleasepool {
            let service = AudioProcessingService(fileManager: mockFileManager)
            weakProcessingService = service
            
            // Use the service briefly
            _ = service.checkSpeechRecognitionStatus()
        }
        
        // Service should be deallocated
        XCTAssertNil(weakProcessingService)
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentProcessing() {
        let concurrentExpectation = XCTestExpectation(description: "Concurrent processing")
        concurrentExpectation.expectedFulfillmentCount = 3
        
        // Setup multiple audio files
        for i in 1...3 {
            let scriptID = UUID()
            let audioURL = testDirectory.appendingPathComponent("concurrent_\(i).m4a")
            let originalURL = testDirectory.appendingPathComponent("concurrent_\(i)_original.m4a")
            
            mockFileManager.mockFiles[scriptID] = audioURL
            mockFileManager.mockOriginalFiles[scriptID] = originalURL
            
            do {
                try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 1.0)
            } catch {
                XCTFail("Failed to create test audio file \(i): \(error)")
                continue
            }
            
            // Process concurrently
            DispatchQueue.global().async {
                self.audioProcessingService.processRecording(for: scriptID) { _ in
                    concurrentExpectation.fulfill()
                }
            }
        }
        
        wait(for: [concurrentExpectation], timeout: TestConstants.testTimeout * 2)
    }
    
    // MARK: - Edge Cases
    
    func testProcessRecording_EmptyTimestamps() {
        let expectation = XCTestExpectation(description: "Processing with empty timestamps")
        
        // Setup mock file URLs
        let audioURL = testDirectory.appendingPathComponent("empty_timestamps.m4a")
        mockFileManager.mockFiles[testScriptID] = audioURL
        
        do {
            try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 2.0)
        } catch {
            XCTFail("Failed to create test audio file: \(error)")
            return
        }
        
        // Process with zero-duration timestamps
        let emptyTimestamps = (start: 1.0, end: 1.0)
        audioProcessingService.processRecording(
            for: testScriptID,
            trimTimestamps: emptyTimestamps
        ) { success in
            // Should handle empty range gracefully
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    func testProcessRecording_InvalidTimestamps() {
        let expectation = XCTestExpectation(description: "Processing with invalid timestamps")
        
        // Setup mock file URLs
        let audioURL = testDirectory.appendingPathComponent("invalid_timestamps.m4a")
        mockFileManager.mockFiles[testScriptID] = audioURL
        
        do {
            try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 5.0)
        } catch {
            XCTFail("Failed to create test audio file: \(error)")
            return
        }
        
        // Process with invalid timestamps (end before start)
        let invalidTimestamps = (start: 3.0, end: 1.0)
        audioProcessingService.processRecording(
            for: testScriptID,
            trimTimestamps: invalidTimestamps
        ) { success in
            // Should handle invalid range
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    func testTranscribeRecording_VeryShortAudio() {
        let expectation = XCTestExpectation(description: "Transcribing very short audio")
        
        // Setup mock file URLs
        let originalURL = testDirectory.appendingPathComponent("very_short_original.m4a")
        mockFileManager.mockOriginalFiles[testScriptID] = originalURL
        
        do {
            try AudioTestHelper.createMockAudioFile(at: originalURL, duration: 0.1)
        } catch {
            XCTFail("Failed to create very short audio file: \(error)")
            return
        }
        
        // Attempt transcription
        audioProcessingService.transcribeRecording(for: testScriptID) { transcription in
            // Very short audio might not produce transcription
            // Just verify it doesn't crash
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConstants.testTimeout)
    }
    
    // MARK: - Integration Tests
    
    func testFullProcessingPipeline() {
        let processingExpectation = XCTestExpectation(description: "Full processing pipeline")
        
        // Setup mock file URLs
        let audioURL = testDirectory.appendingPathComponent("pipeline_test.m4a")
        let originalURL = testDirectory.appendingPathComponent("pipeline_test_original.m4a")
        
        mockFileManager.mockFiles[testScriptID] = audioURL
        mockFileManager.mockOriginalFiles[testScriptID] = originalURL
        
        do {
            try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 3.0)
        } catch {
            XCTFail("Failed to create test audio file: \(error)")
            return
        }
        
        // First process the recording
        audioProcessingService.processRecording(for: testScriptID) { success in
            XCTAssertTrue(success)
            
            // Then transcribe it
            self.audioProcessingService.transcribeRecording(for: self.testScriptID) { transcription in
                // Both operations should complete
                processingExpectation.fulfill()
            }
        }
        
        wait(for: [processingExpectation], timeout: TestConstants.testTimeout * 2)
    }
}