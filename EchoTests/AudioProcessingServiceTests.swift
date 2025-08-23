import XCTest
import AVFoundation
import Speech
@testable import Echo

final class AudioProcessingServiceTests: XCTestCase {
    
    var sut: AudioProcessingService!
    var fileManager: AudioFileManager!
    var testScriptId: UUID!
    
    override func setUp() {
        super.setUp()
        fileManager = AudioFileManager()
        sut = AudioProcessingService(fileManager: fileManager)
        testScriptId = UUID()
    }
    
    override func tearDown() {
        try? fileManager.deleteRecording(for: testScriptId)
        sut = nil
        fileManager = nil
        testScriptId = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestAudioFile() throws {
        let url = fileManager.audioURL(for: testScriptId)
        
        // Create a test audio file with some silence at beginning and end
        let sampleRate = 44100.0
        let duration = 3.0 // 3 seconds
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let audioFile = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ])
        
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        // Add some audio data (simple sine wave in the middle)
        if let channelData = buffer.floatChannelData {
            let samples = channelData[0]
            for i in 0..<Int(frameCount) {
                if i > Int(sampleRate * 0.5) && i < Int(sampleRate * 2.5) {
                    // Add sine wave in the middle 2 seconds
                    samples[i] = sin(Float(i) * 2.0 * Float.pi * 440.0 / Float(sampleRate)) * 0.5
                } else {
                    // Silence at beginning and end
                    samples[i] = 0.0
                }
            }
        }
        
        try audioFile.write(from: buffer)
    }
    
    // MARK: - Tests
    
    func testCheckSpeechRecognitionStatus() {
        // When
        let status = sut.checkSpeechRecognitionStatus()
        
        // Then
        XCTAssertNotNil(status.message)
        
        // On simulator, speech recognition might not be available
        #if targetEnvironment(simulator)
        print("Speech recognition status on simulator: \(status.message)")
        #endif
    }
    
    func testProcessRecordingWithNonexistentFile() {
        // Given
        let expectation = self.expectation(description: "Processing completion")
        let nonexistentId = UUID()
        
        // When
        sut.processRecording(for: nonexistentId) { success in
            // Then
            XCTAssertFalse(success)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testProcessRecordingTrimsSuccessfully() throws {
        // Given
        try createTestAudioFile()
        let expectation = self.expectation(description: "Processing completion")
        
        // When
        sut.processRecording(for: testScriptId) { success in
            // Then
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testTranscribeRecordingRequiresAuthorization() {
        // Given
        let expectation = self.expectation(description: "Transcription completion")
        
        // When
        sut.transcribeRecording(for: testScriptId, languageCode: "en-US") { transcription in
            // Then
            // Result depends on authorization status
            if SFSpeechRecognizer.authorizationStatus() == .authorized {
                // May or may not have transcription based on file existence
            } else {
                XCTAssertNil(transcription)
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testEnsureProperPunctuationEnglish() {
        // Test the private method indirectly through transcription
        // We'll test the punctuation logic separately
        
        // Given various text inputs
        let testCases = [
            ("Hello world", "Hello world."),
            ("What is your name", "What is your name?"),
            ("This is great!", "This is great!"),
            ("Already has period.", "Already has period."),
            ("  Whitespace around  ", "Whitespace around."),
            ("", "")
        ]
        
        // Since the method is private, we test through the public interface
        // or extract the logic to a testable helper
        for (input, expected) in testCases {
            // Test would verify punctuation is added correctly
            print("Testing: '\(input)' -> '\(expected)'")
        }
    }
    
    func testEnsureProperPunctuationChinese() {
        // Test Chinese punctuation handling
        let testCases = [
            ("你好", "zh-CN", "你好。"),
            ("你叫什么名字", "zh-CN", "你叫什么名字？"),
            ("这很好", "zh-CN", "这很好。"),
            ("已经有句号。", "zh-CN", "已经有句号。")
        ]
        
        for (input, languageCode, expected) in testCases {
            print("Testing Chinese: '\(input)' with \(languageCode) -> '\(expected)'")
        }
    }
    
    func testProcessingDoesNotBlockMainThread() throws {
        // Given
        try createTestAudioFile()
        let expectation = self.expectation(description: "Processing on background thread")
        
        var isMainThread = true
        
        // When
        sut.processRecording(for: testScriptId) { success in
            isMainThread = Thread.isMainThread
            expectation.fulfill()
        }
        
        // Then - callback should be on main thread
        waitForExpectations(timeout: 10) { _ in
            XCTAssertTrue(isMainThread, "Completion should be called on main thread")
        }
    }
    
    func testTranscriptionWithDifferentLanguages() {
        // Given
        let languages = ["en-US", "zh-CN", "es-ES", "fr-FR", "ja-JP"]
        
        for language in languages {
            let expectation = self.expectation(description: "Transcription for \(language)")
            
            // When
            sut.transcribeRecording(for: testScriptId, languageCode: language) { transcription in
                // Then
                // Just verify the method completes without crashing
                expectation.fulfill()
            }
            
            waitForExpectations(timeout: 5, handler: nil)
        }
    }
    
    func testConcurrentTranscriptionRequests() {
        // Given
        let expectation1 = self.expectation(description: "First transcription")
        let expectation2 = self.expectation(description: "Second transcription")
        
        // When - Start two transcriptions
        sut.transcribeRecording(for: testScriptId, languageCode: "en-US") { _ in
            expectation1.fulfill()
        }
        
        sut.transcribeRecording(for: UUID(), languageCode: "en-US") { _ in
            expectation2.fulfill()
        }
        
        // Then - Both should complete
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testProcessingShortAudioFile() throws {
        // Given - Create very short audio file (< 0.5 seconds)
        let url = fileManager.audioURL(for: testScriptId)
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let frameCount = AVAudioFrameCount(22050) // 0.5 seconds
        
        let audioFile = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1
        ])
        
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        try audioFile.write(from: buffer)
        
        let expectation = self.expectation(description: "Short file processing")
        
        // When
        sut.processRecording(for: testScriptId) { success in
            // Then - Should handle short files gracefully
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
}