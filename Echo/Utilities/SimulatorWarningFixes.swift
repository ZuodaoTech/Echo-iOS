import Foundation

/// Utilities to suppress common simulator warnings
struct SimulatorWarningFixes {
    
    /// Check if running in simulator
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    /// Configure environment to reduce warnings
    static func configure() {
        guard isSimulator else { return }
        
        // Set environment variables to reduce simulator warnings
        setenv("OS_ACTIVITY_MODE", "disable", 1)
        
        // Disable Core Data debugging in simulator
        UserDefaults.standard.set(false, forKey: "com.apple.CoreData.SQLDebug")
        UserDefaults.standard.set(false, forKey: "com.apple.CoreData.Logging.stderr")
    }
}