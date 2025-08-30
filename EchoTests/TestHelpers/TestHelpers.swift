import XCTest
import Foundation
import CoreData
import AVFoundation
@testable import Echo

// MARK: - Test Constants
enum TestConstants {
    static let testTimeout: TimeInterval = 5.0
    static let shortTimeout: TimeInterval = 1.0
    static let testScriptID = UUID()
    static let testScriptText = "This is a test self-talk script for unit testing."
}

// MARK: - Core Data Test Helper
class CoreDataTestHelper {
    
    /// Creates an in-memory Core Data stack for testing
    static func createInMemoryPersistenceController() -> PersistenceController {
        return PersistenceController(inMemory: true)
    }
    
    /// Creates a test context with sample data
    static func createTestContextWithSampleData() -> NSManagedObjectContext {
        let controller = createInMemoryPersistenceController()
        let context = controller.container.viewContext
        
        // Create test tag
        let testTag = Tag.findOrCreateNormalized(name: "Test Category", in: context)
        
        // Create test script
        let testScript = SelftalkScript.create(
            scriptText: TestConstants.testScriptText,
            repetitions: 3,
            privateMode: false,
            in: context
        )
        testScript.id = TestConstants.testScriptID
        testScript.addToTags(testTag)
        
        try! context.save()
        return context
    }
    
    /// Waits for Core Data to finish all pending operations
    static func waitForCoreData(context: NSManagedObjectContext, timeout: TimeInterval = TestConstants.testTimeout) {
        let expectation = XCTestExpectation(description: "Core Data operations complete")
        
        context.perform {
            expectation.fulfill()
        }
        
        _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
    }
}

// MARK: - Audio Test Helper
class AudioTestHelper {
    
    /// Creates a temporary directory for test audio files
    static func createTestAudioDirectory() -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let testDirectory = tempDirectory.appendingPathComponent("EchoTests")
        
        try! FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        return testDirectory
    }
    
    /// Creates a mock audio file for testing
    static func createMockAudioFile(at url: URL, duration: TimeInterval = 5.0) throws {
        // Create a simple sine wave audio file for testing
        let sampleRate = 44100.0
        let frequency = 440.0 // A4 note
        let amplitude: Float = 0.3
        
        let frameCount = Int(duration * sampleRate)
        
        // Audio format
        var format = AudioStreamBasicDescription()
        format.mSampleRate = sampleRate
        format.mFormatID = kAudioFormatLinearPCM
        format.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
        format.mBitsPerChannel = 32
        format.mChannelsPerFrame = 1
        format.mBytesPerFrame = 4
        format.mFramesPerPacket = 1
        format.mBytesPerPacket = 4
        
        // Create audio file
        var audioFile: ExtAudioFileRef?
        let createResult = ExtAudioFileCreateWithURL(
            url as CFURL,
            kAudioFileM4AType,
            &format,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &audioFile
        )
        
        guard createResult == noErr, let file = audioFile else {
            throw AudioServiceError.recordingFailed
        }
        
        // Generate and write audio data
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        var frameOffset = 0
        while frameOffset < frameCount {
            let framesToWrite = min(bufferSize, frameCount - frameOffset)
            
            for i in 0..<framesToWrite {
                let sample = sin(2.0 * .pi * frequency * Double(frameOffset + i) / sampleRate)
                buffer[i] = Float(sample) * amplitude
            }
            
            var bufferList = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(
                    mNumberChannels: 1,
                    mDataByteSize: UInt32(framesToWrite * MemoryLayout<Float>.size),
                    mData: UnsafeMutableRawPointer(buffer)
                )
            )
            
            var framesToWriteUInt32 = UInt32(framesToWrite)
            let writeResult = ExtAudioFileWrite(file, framesToWriteUInt32, &bufferList)
            
            guard writeResult == noErr else {
                ExtAudioFileDispose(file)
                throw AudioServiceError.recordingFailed
            }
            
            frameOffset += framesToWrite
        }
        
        ExtAudioFileDispose(file)
    }
    
    /// Cleanup test audio files
    static func cleanupTestAudioFiles(in directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }
}

// MARK: - Async Test Helper
class AsyncTestHelper {
    
    /// Helper to test async operations with timeout
    static func testAsync<T>(
        timeout: TimeInterval = TestConstants.testTimeout,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the operation
            group.addTask {
                try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TestError.timeout
            }
            
            // Return first completed result
            guard let result = try await group.next() else {
                throw TestError.timeout
            }
            
            // Cancel remaining tasks
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Test Error
enum TestError: Error, LocalizedError {
    case timeout
    case mockFailure(String)
    case setupError(String)
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Test operation timed out"
        case .mockFailure(let message):
            return "Mock failure: \(message)"
        case .setupError(let message):
            return "Test setup error: \(message)"
        }
    }
}

// MARK: - XCTest Extensions
extension XCTestCase {
    
    /// Wait for expectation with default timeout
    func wait(for expectations: [XCTestExpectation], timeout: TimeInterval = TestConstants.testTimeout) {
        let result = XCTWaiter.wait(for: expectations, timeout: timeout)
        XCTAssertEqual(result, .completed, "Expectation failed to complete within timeout")
    }
    
    /// Assert that an async operation completes within timeout
    func assertAsyncCompletes<T>(
        timeout: TimeInterval = TestConstants.testTimeout,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await AsyncTestHelper.testAsync(timeout: timeout, operation: operation)
    }
    
    /// Assert that an error is thrown
    func assertThrowsError<T>(
        _ operation: () throws -> T,
        _ errorHandler: (Error) -> Void = { _ in }
    ) {
        XCTAssertThrowsError(try operation(), errorHandler)
    }
    
    /// Assert that an async error is thrown
    func assertAsyncThrowsError<T>(
        _ operation: () async throws -> T,
        _ errorHandler: (Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected error to be thrown")
        } catch {
            errorHandler(error)
        }
    }
}