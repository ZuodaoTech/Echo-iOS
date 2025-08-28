import Foundation
import SwiftUI

/// Configuration for optimizing app launch performance
struct AppLaunchOptimizer {
    
    /// Priority levels for initialization tasks
    enum Priority {
        case critical   // Must complete before UI appears
        case high      // Should complete soon after launch
        case normal    // Can be deferred
        case low       // Background tasks
    }
    
    /// Optimize launch performance by deferring non-critical tasks
    static func performDeferredInitialization() {
        Task(priority: .background) {
            // Low priority tasks
            await performLowPriorityTasks()
        }
        
        Task(priority: .utility) {
            // Normal priority tasks
            await performNormalPriorityTasks()
        }
        
        Task(priority: .userInitiated) {
            // High priority tasks
            await performHighPriorityTasks()
        }
    }
    
    private static func performHighPriorityTasks() async {
        // Don't initialize AudioCoordinator on launch anymore
        // It will be initialized lazily when first needed
    }
    
    private static func performNormalPriorityTasks() async {
        // Don't pre-warm localization on launch
        // It will be initialized when actually needed
        
        // Check for app updates or migrations
        await checkForDataMigration()
    }
    
    private static func performLowPriorityTasks() async {
        // Analytics, crash reporting, etc.
        // Clean up old audio files
        await cleanupOrphanedAudioFiles()
    }
    
    private static func checkForDataMigration() async {
        // Check if any Core Data migration is needed
        // This runs in background to not block launch
    }
    
    private static func cleanupOrphanedAudioFiles() async {
        // Clean up audio files without corresponding Core Data entries
        // This is a maintenance task that can run in background
    }
    
    /// Measure and log app launch time
    static func measureLaunchTime(from startTime: Date) {
        let launchTime = Date().timeIntervalSince(startTime)
        print("App launch completed in \(String(format: "%.2f", launchTime)) seconds")
        
        #if DEBUG
        if launchTime > 1.0 {
            print("⚠️ Launch time exceeded 1 second threshold")
        }
        #endif
    }
}

/// Extension to track app launch metrics
extension AppLaunchOptimizer {
    
    /// Key moments in app launch sequence
    struct LaunchMetrics {
        static var appInitStart = Date()
        static var coreDataReady: Date?
        static var uiReady: Date?
        static var fullyLoaded: Date?
        
        static func printReport() {
            guard let coreDataTime = coreDataReady,
                  let uiTime = uiReady else { return }
            
            print("=== Launch Performance Report ===")
            print("Core Data: \(coreDataTime.timeIntervalSince(appInitStart))s")
            print("UI Ready: \(uiTime.timeIntervalSince(appInitStart))s")
            
            if let fullTime = fullyLoaded {
                print("Fully Loaded: \(fullTime.timeIntervalSince(appInitStart))s")
            }
        }
    }
}