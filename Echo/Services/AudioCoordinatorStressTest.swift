import Foundation
import XCTest
import Combine
@testable import Echo

/// Stress tests for AudioCoordinator thread safety and robustness
/// These tests simulate real-world scenarios with high concurrency
class AudioCoordinatorStressTest: XCTestCase {
    
    var coordinator: AudioCoordinator!
    var mockScript: SelftalkScript!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Use the singleton coordinator for testing
        coordinator = AudioCoordinator.shared
        
        // Create a mock script for testing
        // Note: This would need to be adapted based on your Core Data setup
        // For now, assuming we can create test scripts
        mockScript = createTestScript()
        
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        // Clean up
        coordinator.stopCurrentOperation()
        cancellables?.removeAll()
        cancellables = nil
        mockScript = nil
        
        try super.tearDownWithError()
    }
    
    private func createTestScript() -> SelftalkScript {
        // This would create a test script - implementation depends on your Core Data setup
        // For now, returning a placeholder that would need to be implemented
        fatalError("createTestScript needs to be implemented based on Core Data setup")
    }
    
    // MARK: - Thread Safety Stress Tests
    
    /// Test concurrent state transitions from multiple threads
    func testConcurrentStateTransitions() throws {
        let expectation = XCTestExpectation(description: "Concurrent state transitions")
        expectation.expectedFulfillmentCount = 100
        
        let concurrentQueue = DispatchQueue(label: "stress.test", attributes: .concurrent)
        
        // Start 100 concurrent operations
        for i in 0..<100 {
            concurrentQueue.async {
                switch i % 4 {
                case 0:
                    // Try to start recording
                    Task {
                        do {
                            await self.coordinator.startRecording(for: self.mockScript)
                        } catch {
                            // Expected to fail sometimes due to concurrency
                        }
                        expectation.fulfill()
                    }
                case 1:
                    // Try to start playback
                    Task {
                        do {
                            await self.coordinator.startPlayback(for: self.mockScript)
                        } catch {
                            // Expected to fail sometimes due to concurrency
                        }
                        expectation.fulfill()
                    }
                case 2:
                    // Stop current operation
                    self.coordinator.stopCurrentOperation()
                    expectation.fulfill()
                case 3:
                    // Validate and recover
                    self.coordinator.validateAndRecover()
                    expectation.fulfill()
                default:
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // After all concurrent operations, coordinator should be in a valid state
        XCTAssertTrue(coordinator.getCurrentState() != nil)
    }
    
    /// Test rapid optimistic UI updates
    func testOptimisticUIStressTest() throws {
        let expectation = XCTestExpectation(description: "Optimistic UI stress test")
        expectation.expectedFulfillmentCount = 50
        
        // Rapid-fire optimistic operations
        for i in 0..<50 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.01) {
                switch i % 3 {
                case 0:
                    self.coordinator.startRecordingOptimistic(for: self.mockScript)
                case 1:
                    self.coordinator.startPlaybackOptimistic(for: self.mockScript)
                case 2:
                    self.coordinator.stopOptimistic()
                default:
                    break
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Give time for all operations to settle
        Thread.sleep(forTimeInterval: 1.0)
        
        // Validate final state
        coordinator.validateAndRecover()
    }
    
    /// Test interruption handling under stress
    func testInterruptionStressTest() throws {
        let expectation = XCTestExpectation(description: "Interruption stress test")
        
        // Start recording
        Task {
            do {
                await coordinator.startRecording(for: mockScript)
                
                // Simulate rapid interruptions
                for _ in 0..<10 {
                    // Simulate interruption
                    NotificationCenter.default.post(
                        name: AudioSessionManager.interruptionBeganNotification,
                        object: nil,
                        userInfo: [
                            "isPhoneCall": Bool.random(),
                            "duration": Double.random(in: 1.0...30.0)
                        ]
                    )
                    
                    // Brief pause
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    
                    // Resume
                    NotificationCenter.default.post(
                        name: AudioSessionManager.interruptionEndedNotification,
                        object: nil
                    )
                }
                
                expectation.fulfill()
                
            } catch {
                XCTFail("Recording failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    /// Test memory pressure and cleanup
    func testMemoryPressureCleanup() throws {
        let expectation = XCTestExpectation(description: "Memory pressure cleanup")
        
        // Create many concurrent operations that will fail
        let operations = Array(0..<1000).map { i in
            return {
                Task {
                    // These operations will mostly fail due to concurrency limits
                    // but should not cause memory leaks
                    do {
                        await self.coordinator.startRecording(for: self.mockScript)
                        await self.coordinator.startPlayback(for: self.mockScript)
                    } catch {
                        // Expected failures
                    }
                    
                    self.coordinator.stopCurrentOperation()
                }
            }
        }
        
        // Execute all operations
        operations.forEach { operation in
            DispatchQueue.global().async {
                operation()
            }
        }
        
        // Wait for operations to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            // Force cleanup
            self.coordinator.validateAndRecover()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Validate that cleanup worked properly
        XCTAssertTrue(coordinator.getCurrentState() != nil)
    }
    
    /// Test state consistency under rapid changes
    func testStateConsistencyStressTest() throws {
        let expectation = XCTestExpectation(description: "State consistency stress test")
        var stateObservations: [AudioCoordinator.UserFacingState] = []
        let observationQueue = DispatchQueue(label: "observation.queue")
        
        // Observe state changes
        coordinator.$userFacingState
            .sink { state in
                observationQueue.async {
                    stateObservations.append(state)
                }
            }
            .store(in: &cancellables)
        
        // Generate rapid state changes
        Task {
            for i in 0..<100 {
                switch i % 4 {
                case 0:
                    try? await coordinator.startRecording(for: mockScript)
                case 1:
                    try? await coordinator.startPlayback(for: mockScript)
                case 2:
                    coordinator.togglePlayback()
                case 3:
                    coordinator.stopCurrentOperation()
                default:
                    break
                }
                
                // Brief pause to allow state updates
                try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
        
        // Analyze state transitions for consistency
        observationQueue.sync {
            XCTAssertGreaterThan(stateObservations.count, 0, "Should have observed state changes")
            
            // Check for invalid state transitions
            for i in 1..<stateObservations.count {
                let previousState = stateObservations[i-1]
                let currentState = stateObservations[i]
                
                // Add validation rules for valid state transitions
                // This would be customized based on your state machine rules
                validateStateTransition(from: previousState, to: currentState)
            }
        }
    }
    
    private func validateStateTransition(from previous: AudioCoordinator.UserFacingState, to current: AudioCoordinator.UserFacingState) {
        // Add your state transition validation logic here
        // For example:
        // - Can't go from recording directly to playing
        // - Must go through idle or processing states
        // - etc.
        
        // This is a placeholder - implement based on your state machine rules
        switch (previous, current) {
        case (.recording, .playing):
            XCTFail("Invalid direct transition from recording to playing")
        default:
            break // Valid transition
        }
    }
    
    // MARK: - Performance Tests
    
    /// Test responsiveness under load
    func testResponsivenessUnderLoad() throws {
        let expectation = XCTestExpectation(description: "Responsiveness under load")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var responseTimes: [Double] = []
        let responseQueue = DispatchQueue(label: "response.queue")
        
        // Generate load while measuring response times
        for i in 0..<50 {
            let operationStart = CFAbsoluteTimeGetCurrent()
            
            coordinator.startRecordingOptimistic(for: mockScript)
            
            // Measure time until UI state updates
            coordinator.$userFacingState
                .first()
                .sink { _ in
                    let responseTime = CFAbsoluteTimeGetCurrent() - operationStart
                    responseQueue.async {
                        responseTimes.append(responseTime)
                        
                        if responseTimes.count == 50 {
                            expectation.fulfill()
                        }
                    }
                }
                .store(in: &cancellables)
            
            // Stop to reset state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.coordinator.stopOptimistic()
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
        
        // Analyze response times
        responseQueue.sync {
            let averageResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
            let maxResponseTime = responseTimes.max() ?? 0
            
            print("Average response time: \(averageResponseTime * 1000) ms")
            print("Max response time: \(maxResponseTime * 1000) ms")
            
            // Assert reasonable response times
            XCTAssertLessThan(averageResponseTime, 0.1, "Average response time should be under 100ms")
            XCTAssertLessThan(maxResponseTime, 0.5, "Max response time should be under 500ms")
        }
    }
}

// MARK: - Helper Extensions

extension AudioCoordinatorStressTest {
    
    /// Helper to create test scenarios
    private func runConcurrentScenario(_ scenario: @escaping () -> Void, count: Int, timeout: TimeInterval) {
        let expectation = XCTestExpectation(description: "Concurrent scenario")
        expectation.expectedFulfillmentCount = count
        
        let concurrentQueue = DispatchQueue(label: "scenario.queue", attributes: .concurrent)
        
        for _ in 0..<count {
            concurrentQueue.async {
                scenario()
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
    }
}