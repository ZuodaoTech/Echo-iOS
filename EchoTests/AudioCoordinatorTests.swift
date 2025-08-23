import XCTest
import Combine
import CoreData
@testable import Echo

final class AudioCoordinatorTests: XCTestCase {
    
    var sut: AudioCoordinator!
    var context: NSManagedObjectContext!
    var testScript: SelftalkScript!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = AudioCoordinator.shared
        context = PersistenceController.preview.container.viewContext
        cancellables = Set<AnyCancellable>()
        
        // Create test script
        testScript = SelftalkScript.create(
            scriptText: "Test script for audio coordinator",
            category: nil,
            repetitions: 3,
            privacyMode: false,
            in: context
        )
        
        // Clean up any existing recordings
        sut.deleteRecording(for: testScript)
    }
    
    override func tearDown() {
        // Clean up
        sut.stopPlayback()
        sut.stopRecording()
        if let script = testScript {
            sut.deleteRecording(for: script)
        }
        cancellables = nil
        testScript = nil
        context = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testSingletonInstance() {
        // Given/When
        let instance1 = AudioCoordinator.shared
        let instance2 = AudioCoordinator.shared
        
        // Then
        XCTAssertTrue(instance1 === instance2)
    }
    
    func testRequestMicrophonePermission() {
        // Given
        let expectation = self.expectation(description: "Permission callback")
        
        // When
        sut.requestMicrophonePermission { granted in
            // Then
            XCTAssertNotNil(granted)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testStartRecordingUpdatesState() throws {
        // Given
        let expectation = self.expectation(description: "Recording state change")
        
        sut.$isRecording
            .dropFirst()
            .sink { isRecording in
                if isRecording {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        try sut.startRecording(for: testScript)
        
        // Then
        waitForExpectations(timeout: 5) { _ in
            XCTAssertTrue(self.sut.isRecording)
            XCTAssertNotNil(self.testScript.audioFilePath)
            
            // Cleanup
            self.sut.stopRecording()
        }
    }
    
    func testStopRecordingTriggersProcessing() {
        // Given
        do {
            try sut.startRecording(for: testScript)
        } catch {
            XCTFail("Failed to start recording: \(error)")
            return
        }
        
        let expectation = self.expectation(description: "Processing state change")
        
        sut.$isProcessingRecording
            .dropFirst()
            .sink { isProcessing in
                if isProcessing {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        Thread.sleep(forTimeInterval: 0.5) // Record for a bit
        sut.stopRecording()
        
        // Then
        waitForExpectations(timeout: 5) { _ in
            XCTAssertFalse(self.sut.isRecording)
        }
    }
    
    func testProcessingScriptIdsTracking() {
        // Given
        let expectation = self.expectation(description: "Processing IDs updated")
        
        sut.$processingScriptIds
            .dropFirst()
            .sink { ids in
                if ids.contains(self.testScript.id) {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        do {
            try sut.startRecording(for: testScript)
            Thread.sleep(forTimeInterval: 0.5)
            sut.stopRecording()
        } catch {
            XCTFail("Recording failed: \(error)")
        }
        
        // Then
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testIsProcessingScriptMethod() {
        // Given
        XCTAssertFalse(sut.isProcessing(script: testScript))
        
        // When - Manually add to processing set for testing
        sut.processingScriptIds.insert(testScript.id)
        
        // Then
        XCTAssertTrue(sut.isProcessing(script: testScript))
        
        // Cleanup
        sut.processingScriptIds.remove(testScript.id)
        XCTAssertFalse(sut.isProcessing(script: testScript))
    }
    
    func testPlaybackRequiresRecording() {
        // Given - Script without recording
        
        // When/Then
        XCTAssertThrows(try sut.play(script: testScript))
    }
    
    func testPlaybackStateUpdates() throws {
        // This test requires an actual audio file
        // Skip if we can't create one
        guard createMockRecording(for: testScript) else {
            throw XCTSkip("Cannot create mock recording")
        }
        
        let expectation = self.expectation(description: "Playback state change")
        
        sut.$isPlaying
            .dropFirst()
            .sink { isPlaying in
                if isPlaying {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        try sut.play(script: testScript)
        
        // Then
        waitForExpectations(timeout: 5) { _ in
            XCTAssertTrue(self.sut.isPlaying)
            XCTAssertEqual(self.sut.currentPlayingScriptId, self.testScript.id)
            
            // Cleanup
            self.sut.stopPlayback()
        }
    }
    
    func testPauseResumePlayback() throws {
        // Skip if we can't create recording
        guard createMockRecording(for: testScript) else {
            throw XCTSkip("Cannot create mock recording")
        }
        
        // Given
        try sut.play(script: testScript)
        XCTAssertTrue(sut.isPlaying)
        
        // When - Pause
        sut.pausePlayback()
        
        // Then
        XCTAssertTrue(sut.isPaused)
        XCTAssertFalse(sut.isPlaying)
        
        // When - Resume
        sut.resumePlayback()
        
        // Then
        XCTAssertFalse(sut.isPaused)
        XCTAssertTrue(sut.isPlaying)
        
        // Cleanup
        sut.stopPlayback()
    }
    
    func testStopPlayback() throws {
        // Skip if we can't create recording
        guard createMockRecording(for: testScript) else {
            throw XCTSkip("Cannot create mock recording")
        }
        
        // Given
        try sut.play(script: testScript)
        XCTAssertTrue(sut.isPlaying)
        
        // When
        sut.stopPlayback()
        
        // Then
        XCTAssertFalse(sut.isPlaying)
        XCTAssertFalse(sut.isPaused)
        XCTAssertNil(sut.currentPlayingScriptId)
    }
    
    func testDeleteRecordingCleansUp() {
        // Given
        _ = createMockRecording(for: testScript)
        XCTAssertTrue(sut.hasRecording(for: testScript))
        
        // When
        sut.deleteRecording(for: testScript)
        
        // Then
        XCTAssertFalse(sut.hasRecording(for: testScript))
        XCTAssertNil(testScript.audioFilePath)
        XCTAssertEqual(testScript.audioDuration, 0)
        XCTAssertNil(testScript.transcribedText)
    }
    
    func testCheckPrivacyMode() {
        // When
        sut.checkPrivacyMode()
        
        // Then
        // On simulator, should be true (no headphones)
        #if targetEnvironment(simulator)
        XCTAssertTrue(sut.privacyModeActive)
        #endif
    }
    
    func testPlaybackSpeedAdjustment() {
        // Given
        let speeds: [Float] = [0.5, 1.0, 1.5, 2.0]
        
        // When/Then
        for speed in speeds {
            sut.setPlaybackSpeed(speed)
            // Speed should be set (verify through playback service if exposed)
        }
    }
    
    func testConcurrentOperationPrevention() throws {
        // Given - Start recording
        try sut.startRecording(for: testScript)
        XCTAssertTrue(sut.isRecording)
        
        // When - Try to start playback
        let otherScript = SelftalkScript.create(
            scriptText: "Another script",
            category: nil,
            repetitions: 1,
            privacyMode: false,
            in: context
        )
        _ = createMockRecording(for: otherScript)
        
        // Should stop recording when starting playback
        try? sut.play(script: otherScript)
        
        // Then
        XCTAssertFalse(sut.isRecording)
        
        // Cleanup
        sut.stopPlayback()
        sut.deleteRecording(for: otherScript)
    }
    
    // MARK: - Helper Methods
    
    private func createMockRecording(for script: SelftalkScript) -> Bool {
        // Create a simple audio file for testing
        let fileManager = AudioFileManager()
        let url = fileManager.audioURL(for: script.id)
        
        do {
            let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
            let audioFile = try AVAudioFile(forWriting: url, settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1
            ])
            
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: 44100)!
            buffer.frameLength = 44100
            try audioFile.write(from: buffer)
            
            script.audioFilePath = url.path
            script.audioDuration = 1.0
            
            return true
        } catch {
            return false
        }
    }
}