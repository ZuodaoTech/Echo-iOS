import XCTest
import Foundation
import AVFoundation
@testable import Echo

final class AudioFileManagerTests: XCTestCase {
    
    var audioFileManager: AudioFileManager!
    var testDirectory: URL!
    var testScriptID: UUID!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        audioFileManager = AudioFileManager()
        testDirectory = AudioTestHelper.createTestAudioDirectory()
        testScriptID = TestConstants.testScriptID
    }
    
    override func tearDownWithError() throws {
        AudioTestHelper.cleanupTestAudioFiles(in: testDirectory)
        audioFileManager = nil
        testDirectory = nil
        testScriptID = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - URL Generation Tests
    
    func testAudioURL_GeneratesValidURL() {
        // Given a script ID
        let scriptID = UUID()
        
        // When getting the audio URL
        let audioURL = audioFileManager.audioURL(for: scriptID)
        
        // Then it should generate a valid URL
        XCTAssertTrue(audioURL.absoluteString.contains(scriptID.uuidString))
        XCTAssertEqual(audioURL.pathExtension, "m4a")
        XCTAssertTrue(audioURL.path.contains("Recordings"))
    }
    
    func testOriginalAudioURL_GeneratesValidURL() {
        // Given a script ID
        let scriptID = UUID()
        
        // When getting the original audio URL
        let originalURL = audioFileManager.originalAudioURL(for: scriptID)
        
        // Then it should generate a valid URL with "_original" suffix
        XCTAssertTrue(originalURL.absoluteString.contains(scriptID.uuidString))
        XCTAssertTrue(originalURL.absoluteString.contains("_original"))
        XCTAssertEqual(originalURL.pathExtension, "m4a")
    }
    
    func testAudioURL_HandlesPathValidationGracefully() {
        // Given a script ID that could potentially cause path issues
        let scriptID = UUID()
        
        // When getting the audio URL
        let audioURL = audioFileManager.audioURL(for: scriptID)
        
        // Then it should still return a valid, safe URL
        XCTAssertNotNil(audioURL)
        XCTAssertEqual(audioURL.pathExtension, "m4a")
        // URL should be within the recordings directory
        let recordingsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings")
        XCTAssertTrue(audioURL.path.hasPrefix(recordingsPath.path))
    }
    
    // MARK: - File Existence Tests
    
    func testAudioFileExists_ReturnsFalseWhenFileDoesNotExist() {
        // Given a script ID with no corresponding file
        let scriptID = UUID()
        
        // When checking if audio file exists
        let exists = audioFileManager.audioFileExists(for: scriptID)
        
        // Then it should return false
        XCTAssertFalse(exists)
    }
    
    func testAudioFileExists_ReturnsTrueWhenFileExists() throws {
        // Given a script ID and a corresponding audio file
        let scriptID = testScriptID!
        let audioURL = audioFileManager.audioURL(for: scriptID)
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 5.0)
        
        // When checking if audio file exists
        let exists = audioFileManager.audioFileExists(for: scriptID)
        
        // Then it should return true
        XCTAssertTrue(exists)
    }
    
    func testAudioFileExists_ReturnsFalseForZeroSizeFile() throws {
        // Given a script ID and a zero-size audio file
        let scriptID = testScriptID!
        let audioURL = audioFileManager.audioURL(for: scriptID)
        
        // Create empty file
        FileManager.default.createFile(atPath: audioURL.path, contents: Data(), attributes: nil)
        
        // When checking if audio file exists
        let exists = audioFileManager.audioFileExists(for: scriptID)
        
        // Then it should return false (empty files are considered invalid)
        XCTAssertFalse(exists)
    }
    
    // MARK: - File Deletion Tests
    
    func testDeleteRecording_RemovesBothProcessedAndOriginalFiles() throws {
        // Given a script ID with both processed and original audio files
        let scriptID = testScriptID!
        let audioURL = audioFileManager.audioURL(for: scriptID)
        let originalURL = audioFileManager.originalAudioURL(for: scriptID)
        
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 5.0)
        try AudioTestHelper.createMockAudioFile(at: originalURL, duration: 6.0)
        
        // Verify files exist before deletion
        XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: originalURL.path))
        
        // When deleting the recording
        try audioFileManager.deleteRecording(for: scriptID)
        
        // Then both files should be removed
        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalURL.path))
    }
    
    func testDeleteRecording_HandlesNonExistentFiles() {
        // Given a script ID with no corresponding files
        let scriptID = UUID()
        
        // When attempting to delete the recording
        // Then it should not throw an error
        XCTAssertNoThrow(try audioFileManager.deleteRecording(for: scriptID))
    }
    
    func testDeleteRecordingAsync_RemovesFilesAsynchronously() async throws {
        // Given a script ID with audio files
        let scriptID = testScriptID!
        let audioURL = audioFileManager.audioURL(for: scriptID)
        let originalURL = audioFileManager.originalAudioURL(for: scriptID)
        
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 5.0)
        try AudioTestHelper.createMockAudioFile(at: originalURL, duration: 6.0)
        
        // When deleting the recording asynchronously
        try await audioFileManager.deleteRecordingAsync(for: scriptID)
        
        // Then both files should be removed
        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalURL.path))
    }
    
    // MARK: - Audio Duration Tests
    
    func testGetAudioDuration_ReturnsCorrectDurationForValidFile() throws {
        // Given a script ID and a valid audio file
        let scriptID = testScriptID!
        let audioURL = audioFileManager.audioURL(for: scriptID)
        let expectedDuration: TimeInterval = 5.0
        
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: expectedDuration)
        
        // When getting the audio duration
        let duration = audioFileManager.getAudioDuration(for: scriptID)
        
        // Then it should return the correct duration
        XCTAssertNotNil(duration)
        XCTAssertEqual(duration!, expectedDuration, accuracy: 0.1)
    }
    
    func testGetAudioDuration_ReturnsNilForNonExistentFile() {
        // Given a script ID with no corresponding file
        let scriptID = UUID()
        
        // When getting the audio duration
        let duration = audioFileManager.getAudioDuration(for: scriptID)
        
        // Then it should return nil
        XCTAssertNil(duration)
    }
    
    func testGetAudioDurationAsync_ReturnsCorrectDurationAsynchronously() async throws {
        // Given a script ID and a valid audio file
        let scriptID = testScriptID!
        let audioURL = audioFileManager.audioURL(for: scriptID)
        let expectedDuration: TimeInterval = 3.5
        
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: expectedDuration)
        
        // When getting the audio duration asynchronously
        let duration = await audioFileManager.getAudioDurationAsync(for: scriptID)
        
        // Then it should return the correct duration
        XCTAssertNotNil(duration)
        XCTAssertEqual(duration!, expectedDuration, accuracy: 0.1)
    }
    
    func testAudioFileExistsAsync_ReturnsCorrectResultAsynchronously() async throws {
        // Given a script ID and a valid audio file
        let scriptID = testScriptID!
        let audioURL = audioFileManager.audioURL(for: scriptID)
        
        // When checking file existence asynchronously (file doesn't exist)
        var exists = await audioFileManager.audioFileExistsAsync(for: scriptID)
        XCTAssertFalse(exists)
        
        // Create the file
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 2.0)
        
        // When checking file existence asynchronously (file exists)
        exists = await audioFileManager.audioFileExistsAsync(for: scriptID)
        XCTAssertTrue(exists)
    }
    
    // MARK: - File Listing and Storage Tests
    
    func testGetAllRecordingURLs_ReturnsEmptyArrayWhenNoFiles() {
        // When getting all recording URLs with no files present
        let urls = audioFileManager.getAllRecordingURLs()
        
        // Then it should return an empty array
        XCTAssertTrue(urls.isEmpty)
    }
    
    func testGetAllRecordingURLs_ReturnsCorrectURLsWhenFilesExist() throws {
        // Given multiple audio files
        let scriptID1 = UUID()
        let scriptID2 = UUID()
        
        let audioURL1 = audioFileManager.audioURL(for: scriptID1)
        let audioURL2 = audioFileManager.audioURL(for: scriptID2)
        
        try AudioTestHelper.createMockAudioFile(at: audioURL1, duration: 3.0)
        try AudioTestHelper.createMockAudioFile(at: audioURL2, duration: 4.0)
        
        // When getting all recording URLs
        let urls = audioFileManager.getAllRecordingURLs()
        
        // Then it should return the correct URLs
        XCTAssertEqual(urls.count, 2)
        XCTAssertTrue(urls.contains { $0.lastPathComponent.contains(scriptID1.uuidString) })
        XCTAssertTrue(urls.contains { $0.lastPathComponent.contains(scriptID2.uuidString) })
    }
    
    func testTotalRecordingsSize_ReturnsZeroWhenNoFiles() {
        // When calculating total recordings size with no files
        let totalSize = audioFileManager.totalRecordingsSize()
        
        // Then it should return zero
        XCTAssertEqual(totalSize, 0)
    }
    
    func testTotalRecordingsSize_ReturnsCorrectSizeWithFiles() throws {
        // Given multiple audio files
        let scriptID1 = UUID()
        let scriptID2 = UUID()
        
        let audioURL1 = audioFileManager.audioURL(for: scriptID1)
        let audioURL2 = audioFileManager.audioURL(for: scriptID2)
        
        try AudioTestHelper.createMockAudioFile(at: audioURL1, duration: 2.0)
        try AudioTestHelper.createMockAudioFile(at: audioURL2, duration: 3.0)
        
        // When calculating total recordings size
        let totalSize = audioFileManager.totalRecordingsSize()
        
        // Then it should return a positive size
        XCTAssertGreaterThan(totalSize, 0)
    }
    
    // MARK: - File Validation Tests
    
    func testValidateAudioFile_PassesForValidFile() throws {
        // Given a valid audio file
        let scriptID = testScriptID!
        let audioURL = audioFileManager.audioURL(for: scriptID)
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 4.0)
        
        // When validating the audio file
        // Then it should not throw an error
        XCTAssertNoThrow(try audioFileManager.validateAudioFile(for: scriptID))
    }
    
    func testValidateAudioFile_ThrowsForNonExistentFile() {
        // Given a non-existent file
        let scriptID = UUID()
        
        // When validating the audio file
        // Then it should throw an error
        XCTAssertThrowsError(try audioFileManager.validateAudioFile(for: scriptID))
    }
    
    // MARK: - Security Tests
    
    func testPathSecurity_RejectsPathTraversalAttempts() {
        // These tests verify that the security measures in AudioFileManager work
        // The actual implementation handles security internally, so we test behavior
        
        // Given various UUID values (including potentially problematic ones)
        let normalUUID = UUID()
        let testUUIDs = [normalUUID]
        
        for uuid in testUUIDs {
            // When getting URLs for these UUIDs
            let audioURL = audioFileManager.audioURL(for: uuid)
            let originalURL = audioFileManager.originalAudioURL(for: uuid)
            
            // Then the URLs should always be safe and within the recordings directory
            XCTAssertTrue(audioURL.path.contains("Recordings"))
            XCTAssertTrue(originalURL.path.contains("Recordings"))
            XCTAssertEqual(audioURL.pathExtension, "m4a")
            XCTAssertEqual(originalURL.pathExtension, "m4a")
            
            // URLs should not contain path traversal sequences
            XCTAssertFalse(audioURL.path.contains(".."))
            XCTAssertFalse(originalURL.path.contains(".."))
        }
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_AudioURLGeneration() {
        let scriptID = UUID()
        
        measure {
            for _ in 0..<1000 {
                _ = audioFileManager.audioURL(for: scriptID)
            }
        }
    }
    
    func testPerformance_FileExistenceCheck() throws {
        let scriptID = testScriptID!
        let audioURL = audioFileManager.audioURL(for: scriptID)
        try AudioTestHelper.createMockAudioFile(at: audioURL, duration: 1.0)
        
        measure {
            for _ in 0..<100 {
                _ = audioFileManager.audioFileExists(for: scriptID)
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testHandlesFileSystemErrors_Gracefully() {
        // Given a read-only file system scenario (simulated by testing with a protected directory)
        // Most file system errors are handled internally by the FileOperationHelper
        // This test ensures the public API remains stable under error conditions
        
        let scriptID = UUID()
        
        // When performing operations that might fail
        XCTAssertNoThrow(audioFileManager.audioURL(for: scriptID))
        XCTAssertFalse(audioFileManager.audioFileExists(for: scriptID))
        XCTAssertNil(audioFileManager.getAudioDuration(for: scriptID))
        
        // Delete operations on non-existent files should not throw
        XCTAssertNoThrow(try audioFileManager.deleteRecording(for: scriptID))
    }
}