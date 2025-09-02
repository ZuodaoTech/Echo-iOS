import Foundation
import os.log

/// Analytics service for tracking audio interruptions and user recovery patterns
/// Helps improve the user experience by understanding common interruption scenarios
final class InterruptionAnalytics {
    
    // MARK: - Singleton
    
    static let shared = InterruptionAnalytics()
    private init() {
        setupLogging()
    }
    
    // MARK: - Analytics Data Models
    
    struct InterruptionEvent {
        let id = UUID()
        let timestamp = Date()
        let type: InterruptionType
        let duration: TimeInterval
        let recordingDuration: TimeInterval
        let isPhoneCall: Bool
        let recoveryAction: RecoveryAction?
        let timeTaken: TimeInterval?
        
        enum InterruptionType: String, CaseIterable {
            case phoneCall = "phone_call"
            case siri = "siri"
            case notification = "notification"
            case audioRoute = "audio_route_change"
            case backgroundApp = "background_app"
            case unknown = "unknown"
        }
        
        enum RecoveryAction: String, CaseIterable {
            case continueRecording = "continue"
            case savePartial = "save_partial"
            case startOver = "start_over"
            case abandon = "abandon"
        }
    }
    
    struct SessionMetrics {
        let sessionId = UUID()
        let startTime = Date()
        var endTime: Date?
        var interruptions: [InterruptionEvent] = []
        var totalRecordingTime: TimeInterval = 0
        var successfulRecordings: Int = 0
        var abandonedRecordings: Int = 0
    }
    
    // MARK: - Private Properties
    
    private var currentSession: SessionMetrics?
    private var analytics: [InterruptionEvent] = []
    private let logger = Logger(subsystem: "Echo", category: "InterruptionAnalytics")
    private let analyticsQueue = DispatchQueue(label: "analytics.queue", qos: .utility)
    
    // Persistence
    private var analyticsURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                   in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("interruption_analytics.json")
    }
    
    // MARK: - Session Management
    
    func startSession() {
        analyticsQueue.async {
            self.currentSession = SessionMetrics()
            self.logger.info("📊 Analytics session started")
        }
    }
    
    func endSession() {
        analyticsQueue.async {
            guard var session = self.currentSession else { return }
            
            session.endTime = Date()
            self.logSessionSummary(session)
            self.currentSession = nil
        }
    }
    
    // MARK: - Event Tracking
    
    func trackInterruption(
        type: InterruptionEvent.InterruptionType,
        duration: TimeInterval,
        recordingDuration: TimeInterval,
        isPhoneCall: Bool = false
    ) {
        analyticsQueue.async {
            let event = InterruptionEvent(
                type: type,
                duration: duration,
                recordingDuration: recordingDuration,
                isPhoneCall: isPhoneCall,
                recoveryAction: nil,
                timeTaken: nil
            )
            
            self.analytics.append(event)
            self.currentSession?.interruptions.append(event)
            
            self.logger.info("📊 Interruption tracked: \\(type.rawValue), duration: \\(duration)s, recording: \\(recordingDuration)s")</event>
            
            // Save to disk periodically
            if self.analytics.count % 10 == 0 {
                self.persistAnalytics()
            }
        }
    }
    
    func trackRecoveryAction(
        for interruptionId: UUID,
        action: InterruptionEvent.RecoveryAction,
        timeTaken: TimeInterval
    ) {
        analyticsQueue.async {
            // Find and update the interruption event
            if let index = self.analytics.firstIndex(where: { $0.id == interruptionId }) {
                var event = self.analytics[index]
                let updatedEvent = InterruptionEvent(
                    type: event.type,
                    duration: event.duration,
                    recordingDuration: event.recordingDuration,
                    isPhoneCall: event.isPhoneCall,
                    recoveryAction: action,
                    timeTaken: timeTaken
                )
                self.analytics[index] = updatedEvent
                
                // Update current session
                if let sessionIndex = self.currentSession?.interruptions.firstIndex(where: { $0.id == interruptionId }) {
                    self.currentSession?.interruptions[sessionIndex] = updatedEvent
                }
                
                self.logger.info("📊 Recovery action tracked: \\(action.rawValue), time: \\(timeTaken)s")</event>
            }
        }
    }
    
    func trackSuccessfulRecording(duration: TimeInterval) {
        analyticsQueue.async {
            self.currentSession?.successfulRecordings += 1
            self.currentSession?.totalRecordingTime += duration
            
            self.logger.info("📊 Successful recording: \\(duration)s")</duration>
        }
    }
    
    func trackAbandonedRecording(reason: String) {
        analyticsQueue.async {
            self.currentSession?.abandonedRecordings += 1
            
            self.logger.info("📊 Abandoned recording: \\(reason)")</reason>
        }
    }
    
    // MARK: - Analytics Insights
    
    struct AnalyticsInsights {
        let totalInterruptions: Int
        let mostCommonInterruption: InterruptionEvent.InterruptionType
        let averageRecoveryTime: TimeInterval
        let successRate: Double
        let phoneCallFrequency: Double
        let preferredRecoveryAction: InterruptionEvent.RecoveryAction
        let averageInterruptionDuration: TimeInterval
        let insights: [String]
    }
    
    func generateInsights() -> AnalyticsInsights {
        return analyticsQueue.sync {
            loadAnalyticsIfNeeded()
            
            guard !analytics.isEmpty else {
                return AnalyticsInsights(
                    totalInterruptions: 0,
                    mostCommonInterruption: .unknown,
                    averageRecoveryTime: 0,
                    successRate: 1.0,
                    phoneCallFrequency: 0,
                    preferredRecoveryAction: .continueRecording,
                    averageInterruptionDuration: 0,
                    insights: ["No interruption data available"]
                )
            }
            
            let total = analytics.count
            let phoneCallCount = analytics.filter { $0.isPhoneCall }.count
            let recoveredEvents = analytics.filter { $0.recoveryAction != nil }
            
            // Most common interruption type
            let interruptionCounts = Dictionary(grouping: analytics, by: { $0.type })
                .mapValues { $0.count }
            let mostCommon = interruptionCounts.max(by: { $0.value < $1.value })?.key ?? .unknown
            
            // Average recovery time
            let recoveryTimes = recoveredEvents.compactMap { $0.timeTaken }
            let avgRecoveryTime = recoveryTimes.isEmpty ? 0 : recoveryTimes.reduce(0, +) / Double(recoveryTimes.count)
            
            // Success rate (based on recovery actions)
            let successfulRecoveries = recoveredEvents.filter { 
                $0.recoveryAction == .continueRecording || $0.recoveryAction == .savePartial 
            }.count
            let successRate = recoveredEvents.isEmpty ? 1.0 : Double(successfulRecoveries) / Double(recoveredEvents.count)
            
            // Preferred recovery action
            let actionCounts = Dictionary(grouping: recoveredEvents, by: { $0.recoveryAction! })
                .mapValues { $0.count }
            let preferredAction = actionCounts.max(by: { $0.value < $1.value })?.key ?? .continueRecording
            
            // Average interruption duration
            let avgDuration = analytics.reduce(0) { $0 + $1.duration } / Double(analytics.count)
            
            // Generate insights
            var insights: [String] = []
            
            if phoneCallCount > total / 2 {
                insights.append("Phone calls are your main interruption source (\\(phoneCallCount)/\\(total))")</total>
            }
            
            if avgRecoveryTime > 10 {
                insights.append("Users take \\(Int(avgRecoveryTime))s on average to decide on recovery")</avgRecoveryTime>
            }
            
            if successRate < 0.7 {
                insights.append("Low recovery success rate (\\(Int(successRate * 100))%) - consider UX improvements")</successRate>
            }
            
            if mostCommon == .unknown {
                insights.append("Many interruptions are unclassified - improve detection")
            }
            
            if avgDuration > 30 {
                insights.append("Long interruptions (avg \\(Int(avgDuration))s) suggest user workflow issues")</avgDuration>
            }
            
            return AnalyticsInsights(
                totalInterruptions: total,
                mostCommonInterruption: mostCommon,
                averageRecoveryTime: avgRecoveryTime,
                successRate: successRate,
                phoneCallFrequency: Double(phoneCallCount) / Double(total),
                preferredRecoveryAction: preferredAction,
                averageInterruptionDuration: avgDuration,
                insights: insights
            )
        }
    }
    
    // MARK: - Persistence
    
    private func persistAnalytics() {
        do {
            let data = try JSONEncoder().encode(analytics)
            try data.write(to: analyticsURL)
            logger.debug("📊 Analytics saved to disk (\\(analytics.count) events)")</analytics>
        } catch {
            logger.error("📊 Failed to save analytics: \\(error)")</error>
        }
    }
    
    private func loadAnalyticsIfNeeded() {
        guard analytics.isEmpty else { return }
        
        do {
            let data = try Data(contentsOf: analyticsURL)
            analytics = try JSONDecoder().decode([InterruptionEvent].self, from: data)
            logger.debug("📊 Analytics loaded from disk (\\(analytics.count) events)")</analytics>
        } catch {
            // File doesn't exist yet or is corrupted - start fresh
            analytics = []
            logger.debug("📊 Starting fresh analytics (no existing data)")
        }
    }
    
    // MARK: - Debugging and Logging
    
    private func setupLogging() {
        #if DEBUG
        // In debug builds, we can be more verbose
        logger.debug("📊 InterruptionAnalytics initialized")
        #endif
    }
    
    private func logSessionSummary(_ session: SessionMetrics) {
        let duration = session.endTime?.timeIntervalSince(session.startTime) ?? 0
        
        logger.info("""
        📊 Session Summary:
        - Duration: \\(Int(duration))s
        - Successful recordings: \\(session.successfulRecordings)
        - Abandoned recordings: \\(session.abandonedRecordings)
        - Interruptions: \\(session.interruptions.count)
        - Total recording time: \\(Int(session.totalRecordingTime))s
        """)
    }
    
    func printDebugSummary() {
        analyticsQueue.async {
            self.loadAnalyticsIfNeeded()
            let insights = self.generateInsights()
            
            print("""
            
            📊 INTERRUPTION ANALYTICS SUMMARY
            ================================
            Total Interruptions: \\(insights.totalInterruptions)
            Most Common Type: \\(insights.mostCommonInterruption.rawValue)
            Phone Call Frequency: \\(Int(insights.phoneCallFrequency * 100))%
            Success Rate: \\(Int(insights.successRate * 100))%
            Avg Recovery Time: \\(Int(insights.averageRecoveryTime))s
            Preferred Action: \\(insights.preferredRecoveryAction.rawValue)
            
            Key Insights:
            """)
            
            for insight in insights.insights {
                print("• \\(insight)")</insight>
            }
            
            print("================================\n")
        }
    }
    
    // MARK: - Privacy and Data Management
    
    func clearAnalytics() {
        analyticsQueue.async {
            self.analytics.removeAll()
            self.currentSession = nil
            
            // Remove file
            try? FileManager.default.removeItem(at: self.analyticsURL)
            
            self.logger.info("📊 Analytics cleared")
        }
    }
    
    func exportAnalytics() -> Data? {
        return analyticsQueue.sync {
            loadAnalyticsIfNeeded()
            return try? JSONEncoder().encode(analytics)
        }
    }
}

// MARK: - Codable Support

extension InterruptionAnalytics.InterruptionEvent: Codable {}
extension InterruptionAnalytics.InterruptionEvent.InterruptionType: Codable {}
extension InterruptionAnalytics.InterruptionEvent.RecoveryAction: Codable {}