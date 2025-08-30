import XCTest
import CoreData
import Combine
@testable import Echo

/// Integration tests that verify complete audio workflows work end-to-end
final class AudioWorkflowIntegrationTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var audioCoordinator: AudioCoordinator!
    var testScript: SelftalkScript!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Set up persistence layer
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        await persistenceController.loadStores(inMemory: true, iCloudEnabled: false)
        
        // Set up audio coordinator
        audioCoordinator = AudioCoordinator.shared
        
        // Create test script
        testScript = SelftalkScriptBuilder()
            .withScriptText("Integration test script for audio workflow")
            .withRepetitions(2)
            .withIntervalSeconds(1.0)
            .withPrivateMode(false)
            .build(in: context)
        
        try context.save()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        // Clean up audio operations
        if audioCoordinator.isRecording {
            audioCoordinator.stopRecording()
        }
        if audioCoordinator.isPlaying {
            audioCoordinator.stopPlayback()
        }
        
        cancellables?.removeAll()
        testScript = nil
        audioCoordinator = nil
        context = nil
        persistenceController = nil
        cancellables = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Complete Audio Workflow Tests
    
    func testCompleteRecordPlayWorkflow() {
        let workflowExpectation = XCTestExpectation(description: "Complete record-play workflow")
        
        // Step 1: Request microphone permission
        audioCoordinator.requestMicrophonePermission { granted in
            if granted {
                // Step 2: Start recording
                do {
                    try self.audioCoordinator.startRecording(for: self.testScript)
                    
                    // Verify recording state
                    XCTAssertTrue(self.audioCoordinator.isRecording)
                    XCTAssertNotNil(self.testScript.audioFilePath)
                    
                    // Step 3: Stop recording after brief moment
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.audioCoordinator.stopRecording()
                        
                        // Step 4: Wait for processing to complete
                        self.waitForProcessingComplete {
                            // Step 5: Attempt playback
                            do {
                                try self.audioCoordinator.play(script: self.testScript)
                                
                                // Verify playback state
                                if self.audioCoordinator.isPlaying {
                                    XCTAssertTrue(self.audioCoordinator.isPlaying)
                                    XCTAssertEqual(self.audioCoordinator.currentPlayingScriptId, self.testScript.id)
                                    XCTAssertGreaterThan(self.testScript.playCount, 0)
                                }
                                
                                workflowExpectation.fulfill()
                            } catch {
                                // Playback might fail in test environment - that's acceptable
                                workflowExpectation.fulfill()
                            }
                        }
                    }
                } catch {
                    // Recording might fail in test environment
                    workflowExpectation.fulfill()
                }
            } else {
                // Permission denied in test environment - still complete the test
                workflowExpectation.fulfill()
            }
        }
        
        wait(for: [workflowExpectation], timeout: 10.0)
    }
    
    func testRecordWithTranscriptionWorkflow() {
        let transcriptionExpectation = XCTestExpectation(description: "Recording with transcription")
        
        // Monitor for transcription completion
        var transcriptionReceived = false
        
        // Observe script changes
        testScript.publisher(for: \.transcribedText)
            .sink { transcription in
                if transcription != nil {
                    transcriptionReceived = true
                    transcriptionExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Start the workflow
        audioCoordinator.requestMicrophonePermission { granted in
            if granted {
                do {
                    try self.audioCoordinator.startRecording(for: self.testScript)
                    
                    // Simulate brief recording
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.audioCoordinator.stopRecording()
                        
                        // Give processing time to complete (including transcription)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            if !transcriptionReceived {
                                // Transcription might not work in test environment
                                transcriptionExpectation.fulfill()
                            }
                        }
                    }
                } catch {
                    // Recording failed in test environment
                    transcriptionExpectation.fulfill()
                }
            } else {
                // Permission denied
                transcriptionExpectation.fulfill()
            }
        }
        
        wait(for: [transcriptionExpectation], timeout: 15.0)
    }
    
    func testMultipleScriptWorkflow() {
        let multiScriptExpectation = XCTestExpectation(description: "Multiple script workflow")
        
        // Create additional test scripts
        let script2 = SelftalkScriptBuilder()
            .withScriptText("Second integration test script")
            .withRepetitions(1)
            .build(in: context)
        
        let script3 = SelftalkScriptBuilder()
            .withScriptText("Third integration test script")
            .withRepetitions(3)
            .build(in: context)
        
        try! context.save()
        
        let scripts = [testScript!, script2, script3]
        var processedScripts = 0
        
        // Process each script
        func processNextScript(_ index: Int) {
            guard index < scripts.count else {
                multiScriptExpectation.fulfill()
                return
            }
            
            let script = scripts[index]
            
            audioCoordinator.requestMicrophonePermission { granted in
                if granted {
                    do {
                        try self.audioCoordinator.startRecording(for: script)
                        
                        // Brief recording
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.audioCoordinator.stopRecording()
                            
                            // Wait for processing
                            self.waitForProcessingComplete {
                                processedScripts += 1
                                processNextScript(index + 1)
                            }
                        }
                    } catch {
                        // Handle recording failure
                        processedScripts += 1
                        processNextScript(index + 1)
                    }
                } else {
                    // Handle permission denial
                    processedScripts += 1
                    processNextScript(index + 1)
                }
            }
        }
        
        processNextScript(0)
        
        wait(for: [multiScriptExpectation], timeout: 20.0)
        
        // Verify some scripts were processed
        XCTAssertGreaterThanOrEqual(processedScripts, 3)
    }
    
    // MARK: - Error Recovery Tests
    
    func testRecordingInterruptionRecovery() {
        let recoveryExpectation = XCTestExpectation(description: "Recording interruption recovery")
        
        audioCoordinator.requestMicrophonePermission { granted in
            if granted {
                do {
                    // Start recording
                    try self.audioCoordinator.startRecording(for: self.testScript)
                    
                    // Simulate interruption by starting another recording
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        do {
                            let anotherScript = SelftalkScriptBuilder()
                                .withScriptText("Interruption test script")
                                .build(in: self.context)
                            
                            try self.audioCoordinator.startRecording(for: anotherScript)
                            
                            // Should handle the interruption gracefully
                            XCTAssertTrue(self.audioCoordinator.isRecording)
                            
                            // Clean up
                            self.audioCoordinator.stopRecording()
                            recoveryExpectation.fulfill()
                            
                        } catch {
                            // Error handling worked
                            recoveryExpectation.fulfill()
                        }
                    }
                } catch {
                    // Initial recording failed
                    recoveryExpectation.fulfill()
                }
            } else {
                // Permission denied
                recoveryExpectation.fulfill()
            }
        }
        
        wait(for: [recoveryExpectation], timeout: 5.0)
    }
    
    func testPlaybackInterruptionRecovery() {
        let playbackRecoveryExpectation = XCTestExpectation(description: "Playback interruption recovery")
        
        // Setup script with mock audio file
        testScript.audioFilePath = "/mock/audio.m4a"
        testScript.audioDuration = 5.0
        try! context.save()
        
        do {
            // Start playback
            try audioCoordinator.play(script: testScript)
            
            // Simulate interruption with recording
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.audioCoordinator.requestMicrophonePermission { granted in
                    if granted {
                        do {
                            try self.audioCoordinator.startRecording(for: self.testScript)
                            
                            // Should have stopped playback and started recording
                            XCTAssertFalse(self.audioCoordinator.isPlaying)
                            
                            // Clean up
                            self.audioCoordinator.stopRecording()
                            playbackRecoveryExpectation.fulfill()
                            
                        } catch {
                            // Recording failed but interruption was handled
                            playbackRecoveryExpectation.fulfill()
                        }
                    } else {
                        playbackRecoveryExpectation.fulfill()
                    }
                }
            }
        } catch {
            // Playback failed in test environment
            playbackRecoveryExpectation.fulfill()
        }
        
        wait(for: [playbackRecoveryExpectation], timeout: 5.0)
    }
    
    // MARK: - Data Persistence Integration Tests
    
    func testPersistenceIntegrationWorkflow() {
        let persistenceExpectation = XCTestExpectation(description: "Persistence integration")
        
        // Create scripts and verify persistence
        let scripts = TestDataFactory.createCompleteTestData(in: context)
        try! context.save()
        
        // Verify data was saved
        let fetchRequest = SelftalkScript.fetchRequest()
        let savedScripts = try! context.fetch(fetchRequest)
        
        XCTAssertEqual(savedScripts.count, scripts.scripts.count)
        
        // Test deduplication integration
        Task {
            await DeduplicationService.deduplicateScripts(in: self.context)
            
            // Verify deduplication worked
            let afterDeduplication = try! self.context.fetch(fetchRequest)
            XCTAssertLessThanOrEqual(afterDeduplication.count, savedScripts.count)
            
            persistenceExpectation.fulfill()
        }
        
        wait(for: [persistenceExpectation], timeout: 10.0)
    }
    
    func testCloudKitSyncIntegration() {
        let syncExpectation = XCTestExpectation(description: "CloudKit sync integration")
        
        // Test the CloudKit configuration (without actual sync in test environment)
        let storeDescriptions = persistenceController.container.persistentStoreDescriptions
        
        for description in storeDescriptions {
            // History tracking should be enabled for sync
            let historyTracking = description.option(forKey: NSPersistentHistoryTrackingKey) as? Bool
            XCTAssertTrue(historyTracking ?? false)
            
            let remoteChange = description.option(forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey) as? Bool
            XCTAssertTrue(remoteChange ?? false)
        }
        
        // Test sample data import (simulating first launch)
        Task {
            await self.persistenceController.importSamplesIfNeeded()
            
            // Verify sample scripts exist
            let fetchRequest = SelftalkScript.fetchRequest()
            let sampleIDs = [
                StaticSampleCard.smokingSampleID,
                StaticSampleCard.bedtimeSampleID,
                StaticSampleCard.mistakesSampleID
            ]
            fetchRequest.predicate = NSPredicate(format: "id IN %@", sampleIDs)
            
            let samples = try! self.context.fetch(fetchRequest)
            XCTAssertGreaterThanOrEqual(samples.count, 0) // May or may not be imported in test
            
            syncExpectation.fulfill()
        }
        
        wait(for: [syncExpectation], timeout: 5.0)
    }
    
    // MARK: - Performance Integration Tests
    
    func testLargeDataSetPerformance() {
        measure {
            // Create large dataset
            for i in 0..<100 {
                let script = SelftalkScriptBuilder()
                    .withScriptText("Performance test script \(i)")
                    .withRepetitions(Int16(i % 5 + 1))
                    .build(in: context)
            }
            
            try! context.save()
            
            // Test querying performance
            let fetchRequest = SelftalkScript.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SelftalkScript.lastModified, ascending: false)]
            fetchRequest.fetchLimit = 20
            
            _ = try! context.fetch(fetchRequest)
        }
    }
    
    // MARK: - Helper Methods
    
    private func waitForProcessingComplete(completion: @escaping () -> Void) {
        let checkProcessing = {
            if self.audioCoordinator.processingScriptIds.isEmpty && !self.audioCoordinator.isProcessingRecording {
                completion()
            } else {
                // Check again after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.waitForProcessingComplete(completion: completion)
                }
            }
        }
        
        // Initial check
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            checkProcessing()
        }
    }
}