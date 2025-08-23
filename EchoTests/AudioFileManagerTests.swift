import XCTest
@testable import Echo
import AVFoundation

final class AudioFileManagerTests: XCTestCase {
    
    var sut: AudioFileManager!
    var testScriptId: UUID!
    
    override func setUp() {
        super.setUp()
        sut = AudioFileManager()
        testScriptId = UUID()
        
        // Clean up any existing test files
        cleanupTestFiles()
    }
    
    override func tearDown() {
        cleanupTestFiles()
        sut = nil
        testScriptId = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func cleanupTestFiles() {
        guard let testScriptId = testScriptId else { return }
        try? sut.deleteRecording(for: testScriptId)
    }
    
    private func createTestAudioFile(for scriptId: UUID, isOriginal: Bool = false) throws {
        let url = isOriginal ? sut.originalAudioURL(for: scriptId) : sut.audioURL(for: scriptId)
        
        // Create a simple audio file for testing
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let audioFile = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ])
        
        // Write some audio data
        let frameCount = AVAudioFrameCount(44100) // 1 second of audio
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        try audioFile.write(from: buffer)
    }
    
    // MARK: - Tests
    
    func testAudioURLReturnsCorrectPath() {
        // Given
        let scriptId = UUID()
        
        // When
        let url = sut.audioURL(for: scriptId)
        
        // Then
        XCTAssertTrue(url.path.contains("Recordings"))
        XCTAssertTrue(url.path.contains("\(scriptId.uuidString).m4a"))
        XCTAssertEqual(url.pathExtension, "m4a")
    }
    
    func testOriginalAudioURLReturnsDifferentPath() {
        // Given
        let scriptId = UUID()
        
        // When
        let audioURL = sut.audioURL(for: scriptId)
        let originalURL = sut.originalAudioURL(for: scriptId)
        
        // Then
        XCTAssertNotEqual(audioURL, originalURL)
        XCTAssertTrue(originalURL.path.contains("\(scriptId.uuidString)_original.m4a"))
    }
    
    func testAudioFileExistsReturnsFalseForNonexistentFile() {
        // Given
        let scriptId = UUID()
        
        // When
        let exists = sut.audioFileExists(for: scriptId)
        
        // Then
        XCTAssertFalse(exists)
    }
    
    func testAudioFileExistsReturnsTrueForExistingFile() throws {
        // Given
        try createTestAudioFile(for: testScriptId)
        
        // When
        let exists = sut.audioFileExists(for: testScriptId)
        
        // Then
        XCTAssertTrue(exists)
    }
    
    func testDeleteRecordingRemovesBothFiles() throws {
        // Given
        try createTestAudioFile(for: testScriptId, isOriginal: false)
        try createTestAudioFile(for: testScriptId, isOriginal: true)
        
        let audioURL = sut.audioURL(for: testScriptId)
        let originalURL = sut.originalAudioURL(for: testScriptId)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: originalURL.path))
        
        // When
        try sut.deleteRecording(for: testScriptId)
        
        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalURL.path))
    }
    
    func testDeleteRecordingHandlesMissingFiles() {
        // Given
        let scriptId = UUID()
        
        // When/Then - Should not throw
        XCTAssertNoThrow(try sut.deleteRecording(for: scriptId))
    }
    
    func testGetAudioDurationReturnsNilForNonexistentFile() {
        // Given
        let scriptId = UUID()
        
        // When
        let duration = sut.getAudioDuration(for: scriptId)
        
        // Then
        XCTAssertNil(duration)
    }
    
    func testGetAudioDurationReturnsCorrectDuration() throws {
        // Given
        try createTestAudioFile(for: testScriptId)
        
        // When
        let duration = sut.getAudioDuration(for: testScriptId)
        
        // Then
        XCTAssertNotNil(duration)
        if let duration = duration {
            XCTAssertGreaterThan(duration, 0)
            XCTAssertFalse(duration.isNaN)
            XCTAssertFalse(duration.isInfinite)
        }
    }
    
    func testGetAllRecordingURLsReturnsOnlyM4AFiles() throws {
        // Given
        try createTestAudioFile(for: testScriptId)
        let textFileURL = sut.audioURL(for: UUID()).deletingPathExtension().appendingPathExtension("txt")
        try "test".write(to: textFileURL, atomically: true, encoding: .utf8)
        
        // When
        let urls = sut.getAllRecordingURLs()
        
        // Then
        XCTAssertFalse(urls.isEmpty)
        XCTAssertTrue(urls.allSatisfy { $0.pathExtension == "m4a" })
        XCTAssertFalse(urls.contains { $0.pathExtension == "txt" })
        
        // Cleanup
        try? FileManager.default.removeItem(at: textFileURL)
    }
    
    func testTotalRecordingsSizeCalculatesCorrectly() throws {
        // Given
        let initialSize = sut.totalRecordingsSize()
        try createTestAudioFile(for: testScriptId)
        
        // When
        let newSize = sut.totalRecordingsSize()
        
        // Then
        XCTAssertGreaterThan(newSize, initialSize)
    }
    
    func testRecordingsDirectoryIsCreatedOnInit() {
        // Given
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("Recordings")
        
        // When - AudioFileManager init already called in setUp
        
        // Then
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: recordingsPath.path, isDirectory: &isDirectory)
        XCTAssertTrue(exists)
        XCTAssertTrue(isDirectory.boolValue)
    }
}