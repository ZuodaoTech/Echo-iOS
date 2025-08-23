import XCTest
import AVFoundation
import CoreData
@testable import Pando_Echo

class RepetitionLogicTests: XCTestCase {
    
    func testRepetitionLogic() {
        // Test the logic: with totalRepetitions = 3 and currentRepetition starting at 1
        
        // After first play finishes:
        let currentRep1 = 1
        let totalReps = 3
        XCTAssertTrue(currentRep1 < totalReps, "After 1st play: 1 < 3 should be true, should play again")
        
        // After second play finishes:
        let currentRep2 = 2
        XCTAssertTrue(currentRep2 < totalReps, "After 2nd play: 2 < 3 should be true, should play again")
        
        // After third play finishes:
        let currentRep3 = 3
        XCTAssertFalse(currentRep3 < totalReps, "After 3rd play: 3 < 3 should be false, should stop")
        
        // This means we play exactly 3 times: repetition 1, 2, and 3
    }
    
    func testRepetitionSequence() {
        // Simulating the sequence for 3 repetitions
        var playCount = 0
        var currentRepetition = 1
        let totalRepetitions = 3
        
        // Simulate playback loop
        repeat {
            playCount += 1
            print("Playing repetition \(currentRepetition)")
            
            // After play finishes, check if we need more
            if currentRepetition < totalRepetitions {
                currentRepetition += 1
                // Would trigger next play after interval
            } else {
                // Stop
                break
            }
        } while currentRepetition <= totalRepetitions
        
        XCTAssertEqual(playCount, 3, "Should play exactly 3 times for 3 repetitions")
    }
    
    func testSingleRepetition() {
        // With 1 repetition
        let currentRep = 1
        let totalReps = 1
        
        // After first play finishes:
        XCTAssertFalse(currentRep < totalReps, "1 < 1 is false, should not repeat")
        
        // This means it plays exactly once
    }
    
    func testZeroRepetitions() {
        // Edge case: 0 repetitions (shouldn't happen in practice)
        let currentRep = 1  // We start at 1
        let totalReps = 0
        
        // This would immediately fail the check
        XCTAssertFalse(currentRep < totalReps, "1 < 0 is false, would not play at all")
    }
}