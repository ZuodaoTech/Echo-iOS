import Foundation
import os.log

/// Secure logging utility that conditionally logs based on build configuration
/// and prevents sensitive data from being logged in production
final class SecureLogger {
    
    // MARK: - Log Levels
    
    enum LogLevel {
        case debug
        case info
        case warning
        case error
        case security
    }
    
    // MARK: - Private Properties
    
    private static let subsystem = "xiaolai.Echo"
    private static let debugLogger = OSLog(subsystem: subsystem, category: "debug")
    private static let infoLogger = OSLog(subsystem: subsystem, category: "info")
    private static let warningLogger = OSLog(subsystem: subsystem, category: "warning")
    private static let errorLogger = OSLog(subsystem: subsystem, category: "error")
    private static let securityLogger = OSLog(subsystem: subsystem, category: "security")
    
    // MARK: - Public Methods
    
    /// Log a debug message (only in DEBUG builds)
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let sanitized = sanitizeMessage(message)
        let location = "\(URL(fileURLWithPath: file).lastPathComponent):\(function):\(line)"
        os_log("%{public}@ - %{public}@", log: debugLogger, type: .debug, location, sanitized)
        #endif
    }
    
    /// Log an info message (only in DEBUG builds)
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let sanitized = sanitizeMessage(message)
        let location = "\(URL(fileURLWithPath: file).lastPathComponent):\(function):\(line)"
        os_log("%{public}@ - %{public}@", log: infoLogger, type: .info, location, sanitized)
        #endif
    }
    
    /// Log a warning message (available in all builds)
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let sanitized = sanitizeMessage(message)
        let location = "\(URL(fileURLWithPath: file).lastPathComponent):\(function):\(line)"
        os_log("%{public}@ - %{public}@", log: warningLogger, type: .error, location, sanitized)
    }
    
    /// Log an error message (available in all builds)
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let sanitized = sanitizeMessage(message)
        let location = "\(URL(fileURLWithPath: file).lastPathComponent):\(function):\(line)"
        os_log("%{public}@ - %{public}@", log: errorLogger, type: .error, location, sanitized)
    }
    
    /// Log a security-related message (always logged but sanitized)
    static func security(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let sanitized = sanitizeSensitiveMessage(message)
        let location = "\(URL(fileURLWithPath: file).lastPathComponent):\(function):\(line)"
        os_log("%{public}@ - %{public}@", log: securityLogger, type: .error, location, sanitized)
    }
    
    // MARK: - Private Methods
    
    /// Sanitize log messages to remove potentially sensitive information
    private static func sanitizeMessage(_ message: String) -> String {
        var sanitized = message
        
        // Remove UUIDs (but keep first 8 characters for debugging)
        let uuidPattern = #"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"#
        sanitized = sanitized.replacingOccurrences(of: uuidPattern, with: "UUID(****)", options: .regularExpression)
        
        // Remove file paths (keep only filename)
        let pathPattern = #"/[^/\s]+/[^/\s]*"#
        sanitized = sanitized.replacingOccurrences(of: pathPattern, with: "***", options: .regularExpression)
        
        // Remove potential personal data patterns
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        sanitized = sanitized.replacingOccurrences(of: emailPattern, with: "***@***.***", options: .regularExpression)
        
        return sanitized
    }
    
    /// Extra sanitization for security-related messages
    private static func sanitizeSensitiveMessage(_ message: String) -> String {
        let basicSanitized = sanitizeMessage(message)
        
        // Remove any remaining potentially sensitive data patterns
        var sanitized = basicSanitized
        
        // Remove container identifiers except the first few characters
        sanitized = sanitized.replacingOccurrences(of: #"iCloud\.[a-zA-Z0-9\.]+"#, with: "iCloud.***", options: .regularExpression)
        
        // Remove team identifiers
        sanitized = sanitized.replacingOccurrences(of: #"[A-Z0-9]{10}"#, with: "***", options: .regularExpression)
        
        return sanitized
    }
}

// MARK: - Backward Compatibility

/// Legacy print function replacement that automatically uses SecureLogger
@available(*, deprecated, message: "Use SecureLogger instead")
func debugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let message = items.map { "\($0)" }.joined(separator: separator)
    SecureLogger.debug(message)
    #endif
}