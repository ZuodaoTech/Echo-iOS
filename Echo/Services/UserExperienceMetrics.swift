import Foundation
import UIKit
import os.log

/// Tracks user experience metrics to identify performance and usability issues
/// Focuses on perceived performance and user satisfaction indicators
final class UserExperienceMetrics {
    
    // MARK: - Singleton
    
    static let shared = UserExperienceMetrics()
    private init() {
        setupMetricsCollection()
    }
    
    // MARK: - Metrics Data Models
    
    struct PerformanceMetric {
        let timestamp = Date()
        let operation: String
        let duration: TimeInterval
        let success: Bool
        let context: [String: Any]
    }
    
    struct UserActionMetric {
        let timestamp = Date()
        let action: UserAction
        let duration: TimeInterval?
        let retryCount: Int
        let abandoned: Bool
        
        enum UserAction: String, CaseIterable {
            case startRecording = "start_recording"
            case stopRecording = "stop_recording"
            case startPlayback = "start_playback"
            case pausePlayback = "pause_playback"
            case resumePlayback = "resume_playback"
            case stopPlayback = "stop_playback"
            case createScript = "create_script"
            case editScript = "edit_script"
            case deleteScript = "delete_script"
            case navigateToSettings = "navigate_settings"
            case togglePrivacyMode = "toggle_privacy"
        }
    }
    
    struct SessionMetric {
        let sessionId = UUID()
        let startTime = Date()
        var endTime: Date?
        var screenTransitions: [(String, Date)] = []
        var performanceEvents: [PerformanceMetric] = []
        var userActions: [UserActionMetric] = []
        var crashEvents: [String] = []
        var memoryWarnings: Int = 0
        var lowBatteryEvents: Int = 0
    }
    
    // MARK: - Private Properties
    
    private var currentSession: SessionMetric = SessionMetric()
    private var sessions: [SessionMetric] = []
    private let logger = Logger(subsystem: "Echo", category: "UXMetrics")
    private let metricsQueue = DispatchQueue(label: "ux.metrics", qos: .utility)
    
    // Action tracking
    private var actionStartTimes: [String: Date] = [:]
    private var actionRetryCount: [String: Int] = [:]
    
    // Persistence
    private var metricsURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                   in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("ux_metrics.json")
    }
    
    // MARK: - Session Management
    
    func startNewSession() {
        metricsQueue.async {
            // End current session if active
            if self.currentSession.endTime == nil {
                self.endCurrentSession()
            }
            
            // Start new session
            self.currentSession = SessionMetric()
            self.logger.info("📈 UX Metrics session started")
        }
    }
    
    func endCurrentSession() {
        metricsQueue.async {
            self.currentSession.endTime = Date()
            self.sessions.append(self.currentSession)
            
            // Persist sessions periodically
            if self.sessions.count % 5 == 0 {
                self.persistMetrics()
            }
            
            self.logger.info("📈 UX Metrics session ended")
        }
    }
    
    // MARK: - Performance Tracking
    
    func trackOperation<T>(_ operation: String, 
                          context: [String: Any] = [:], 
                          operation: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let result = try operation()
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            recordPerformanceMetric(
                operation: operation,
                duration: duration,
                success: true,
                context: context
            )
            
            return result
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            recordPerformanceMetric(
                operation: operation,
                duration: duration,
                success: false,
                context: context.merging(["error": error.localizedDescription]) { _, new in new }
            )
            
            throw error
        }
    }
    
    func trackAsyncOperation<T>(_ operation: String,
                              context: [String: Any] = [:],
                              operation: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let result = try await operation()
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            recordPerformanceMetric(
                operation: operation,
                duration: duration,
                success: true,
                context: context
            )
            
            return result
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            recordPerformanceMetric(
                operation: operation,
                duration: duration,
                success: false,
                context: context.merging(["error": error.localizedDescription]) { _, new in new }
            )
            
            throw error
        }
    }
    
    private func recordPerformanceMetric(operation: String, 
                                       duration: TimeInterval, 
                                       success: Bool, 
                                       context: [String: Any]) {
        metricsQueue.async {
            let metric = PerformanceMetric(
                operation: operation,
                duration: duration,
                success: success,
                context: context
            )
            
            self.currentSession.performanceEvents.append(metric)
            
            // Log slow operations
            if duration > 0.5 {
                self.logger.warning("📈 Slow operation: \\(operation) took \\(duration * 1000)ms")</operation>
            }
        }
    }
    
    // MARK: - User Action Tracking
    
    func startUserAction(_ action: UserActionMetric.UserAction) {
        metricsQueue.async {
            let actionKey = action.rawValue
            self.actionStartTimes[actionKey] = Date()
            self.actionRetryCount[actionKey] = 0
        }
    }
    
    func retryUserAction(_ action: UserActionMetric.UserAction) {
        metricsQueue.async {
            let actionKey = action.rawValue
            self.actionRetryCount[actionKey, default: 0] += 1
        }
    }
    
    func completeUserAction(_ action: UserActionMetric.UserAction, success: Bool) {
        metricsQueue.async {
            let actionKey = action.rawValue
            let startTime = self.actionStartTimes[actionKey]
            let retryCount = self.actionRetryCount[actionKey] ?? 0
            
            let duration = startTime?.timeIntervalSinceNow.magnitude
            
            let metric = UserActionMetric(
                action: action,
                duration: duration,
                retryCount: retryCount,
                abandoned: !success
            )
            
            self.currentSession.userActions.append(metric)
            
            // Clean up tracking
            self.actionStartTimes.removeValue(forKey: actionKey)
            self.actionRetryCount.removeValue(forKey: actionKey)
            
            // Log problematic actions
            if retryCount > 2 {
                self.logger.warning("📈 High retry count for \\(action.rawValue): \\(retryCount) retries")</retryCount>
            }
            
            if !success {
                self.logger.info("📈 User abandoned action: \\(action.rawValue)")</action>
            }
        }
    }
    
    // MARK: - Screen Transition Tracking
    
    func trackScreenTransition(to screen: String) {
        metricsQueue.async {
            self.currentSession.screenTransitions.append((screen, Date()))
            self.logger.debug("📈 Screen transition: \\(screen)")</screen>
        }
    }
    
    // MARK: - System Event Tracking
    
    func trackMemoryWarning() {
        metricsQueue.async {
            self.currentSession.memoryWarnings += 1
            self.logger.warning("📈 Memory warning received")
        }
    }
    
    func trackLowBattery() {
        metricsQueue.async {
            self.currentSession.lowBatteryEvents += 1
            self.logger.info("📈 Low battery event")
        }
    }
    
    func trackCrash(reason: String) {
        metricsQueue.async {
            self.currentSession.crashEvents.append(reason)
            self.logger.error("📈 Crash tracked: \\(reason)")</reason>
        }
    }
    
    // MARK: - Analytics and Insights
    
    struct UXInsights {
        let avgSessionDuration: TimeInterval
        let mostUsedFeatures: [UserActionMetric.UserAction]
        let slowestOperations: [String]
        let highRetryActions: [UserActionMetric.UserAction]
        let abandonment Rate: Double
        let memoryPressureFrequency: Double
        let crashRate: Double
        let insights: [String]
    }
    
    func generateUXInsights() -> UXInsights {
        return metricsQueue.sync {
            loadMetricsIfNeeded()
            
            guard !sessions.isEmpty else {
                return UXInsights(
                    avgSessionDuration: 0,
                    mostUsedFeatures: [],
                    slowestOperations: [],
                    highRetryActions: [],
                    abandonmentRate: 0,
                    memoryPressureFrequency: 0,
                    crashRate: 0,
                    insights: ["Insufficient data for insights"]
                )
            }
            
            // Calculate session durations
            let sessionDurations = sessions.compactMap { session in
                guard let endTime = session.endTime else { return nil }
                return endTime.timeIntervalSince(session.startTime)
            }
            let avgSessionDuration = sessionDurations.isEmpty ? 0 : 
                sessionDurations.reduce(0, +) / Double(sessionDurations.count)
            
            // Most used features
            let allActions = sessions.flatMap { $0.userActions }
            let actionCounts = Dictionary(grouping: allActions, by: { $0.action })
                .mapValues { $0.count }
            let mostUsed = actionCounts.sorted { $0.value > $1.value }
                .prefix(5).map { $0.key }
            
            // Slowest operations
            let allPerformanceEvents = sessions.flatMap { $0.performanceEvents }
            let operationTimes = Dictionary(grouping: allPerformanceEvents, by: { $0.operation })
                .mapValues { events in
                    events.reduce(0) { $0 + $1.duration } / Double(events.count)
                }
            let slowest = operationTimes.sorted { $0.value > $1.value }
                .prefix(5).map { $0.key }
            
            // High retry actions
            let actionRetries = Dictionary(grouping: allActions, by: { $0.action })
                .mapValues { actions in
                    actions.reduce(0) { $0 + $1.retryCount } / actions.count
                }
            let highRetry = actionRetries.filter { $0.value > 1 }
                .sorted { $0.value > $1.value }
                .map { $0.key }
            
            // Abandonment rate
            let abandonedActions = allActions.filter { $0.abandoned }.count
            let abandonmentRate = allActions.isEmpty ? 0 : 
                Double(abandonedActions) / Double(allActions.count)
            
            // Memory pressure frequency
            let totalMemoryWarnings = sessions.reduce(0) { $0 + $1.memoryWarnings }
            let memoryPressureFreq = sessions.isEmpty ? 0 : 
                Double(totalMemoryWarnings) / Double(sessions.count)
            
            // Crash rate
            let totalCrashes = sessions.reduce(0) { $0 + $1.crashEvents.count }
            let crashRate = sessions.isEmpty ? 0 : 
                Double(totalCrashes) / Double(sessions.count)
            
            // Generate insights
            var insights: [String] = []
            
            if avgSessionDuration < 60 {
                insights.append("Short sessions (avg \\(Int(avgSessionDuration))s) may indicate usability issues")</avgSessionDuration>
            }
            
            if abandonmentRate > 0.2 {
                insights.append("High abandonment rate (\\(Int(abandonmentRate * 100))%) suggests UX friction")</abandonmentRate>
            }
            
            if memoryPressureFreq > 0.5 {
                insights.append("Frequent memory warnings (\\(memoryPressureFreq)/session) - optimize memory usage")</memoryPressureFreq>
            }
            
            if !highRetry.isEmpty {
                insights.append("High retry actions detected - improve these workflows")
            }
            
            if crashRate > 0.1 {
                insights.append("Crash rate (\\(Int(crashRate * 100))%) needs attention")</crashRate>
            }
            
            return UXInsights(
                avgSessionDuration: avgSessionDuration,
                mostUsedFeatures: Array(mostUsed),
                slowestOperations: Array(slowest),
                highRetryActions: Array(highRetry),
                abandonmentRate: abandonmentRate,
                memoryPressureFrequency: memoryPressureFreq,
                crashRate: crashRate,
                insights: insights
            )
        }
    }
    
    // MARK: - Setup and Monitoring
    
    private func setupMetricsCollection() {
        // Monitor memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.trackMemoryWarning()
        }
        
        // Monitor battery state
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if UIDevice.current.batteryState == .critical {
                self?.trackLowBattery()
            }
        }
        
        // App lifecycle events
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.endCurrentSession()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.startNewSession()
        }
    }
    
    // MARK: - Persistence
    
    private func persistMetrics() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(sessions)
            try data.write(to: metricsURL)
            
            logger.debug("📈 UX Metrics saved (\\(sessions.count) sessions)")</sessions>
        } catch {
            logger.error("📈 Failed to save UX metrics: \\(error)")</error>
        }
    }
    
    private func loadMetricsIfNeeded() {
        guard sessions.isEmpty else { return }
        
        do {
            let data = try Data(contentsOf: metricsURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            sessions = try decoder.decode([SessionMetric].self, from: data)
            logger.debug("📈 UX Metrics loaded (\\(sessions.count) sessions)")</sessions>
        } catch {
            sessions = []
            logger.debug("📈 Starting fresh UX metrics")
        }
    }
    
    // MARK: - Debug and Export
    
    func printDebugSummary() {
        metricsQueue.async {
            let insights = self.generateUXInsights()
            
            print("""
            
            📈 USER EXPERIENCE METRICS
            =========================
            Avg Session Duration: \\(Int(insights.avgSessionDuration))s
            Total Sessions: \\(self.sessions.count)
            Abandonment Rate: \\(Int(insights.abandonmentRate * 100))%
            Memory Warnings/Session: \\(insights.memoryPressureFrequency)
            Crash Rate: \\(Int(insights.crashRate * 100))%
            
            Most Used Features:
            """)
            
            for feature in insights.mostUsedFeatures.prefix(3) {
                print("• \\(feature.rawValue)")</feature>
            }
            
            print("\nSlowest Operations:")
            for operation in insights.slowestOperations.prefix(3) {
                print("• \\(operation)")</operation>
            }
            
            print("\nKey Insights:")
            for insight in insights.insights {
                print("• \\(insight)")</insight>
            }
            
            print("=========================\n")
        }
    }
    
    func exportMetrics() -> Data? {
        return metricsQueue.sync {
            loadMetricsIfNeeded()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try? encoder.encode(sessions)
        }
    }
    
    func clearMetrics() {
        metricsQueue.async {
            self.sessions.removeAll()
            self.currentSession = SessionMetric()
            try? FileManager.default.removeItem(at: self.metricsURL)
            self.logger.info("📈 UX Metrics cleared")
        }
    }
}

// MARK: - Codable Support

extension UserExperienceMetrics.PerformanceMetric: Codable {
    enum CodingKeys: String, CodingKey {
        case timestamp, operation, duration, success
        // Skip context since it contains Any values
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(operation, forKey: .operation)
        try container.encode(duration, forKey: .duration)
        try container.encode(success, forKey: .success)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        operation = try container.decode(String.self, forKey: .operation)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        success = try container.decode(Bool.self, forKey: .success)
        context = [:]
    }
}

extension UserExperienceMetrics.UserActionMetric: Codable {}
extension UserExperienceMetrics.UserActionMetric.UserAction: Codable {}
extension UserExperienceMetrics.SessionMetric: Codable {
    enum CodingKeys: String, CodingKey {
        case sessionId, startTime, endTime, screenTransitions, 
             performanceEvents, userActions, crashEvents, 
             memoryWarnings, lowBatteryEvents
    }
}