import Foundation

/// Lightweight metrics tracking system for behavioral insights
/// Focuses on habit formation patterns without complex analytics infrastructure
class HabitMetrics {
    static let shared = HabitMetrics()
    
    private init() {}
    
    // MARK: - Core Behavioral Events
    
    /// Track when user creates a new script
    static func scriptCreated(scriptId: UUID, textLength: Int) {
        shared.track("script_created", properties: [
            "script_id": scriptId.uuidString,
            "text_length": textLength
        ])
    }
    
    /// Track when user starts their first recording attempt
    static func firstRecordingStarted(scriptId: UUID) {
        shared.track("first_recording_started", properties: [
            "script_id": scriptId.uuidString
        ])
    }
    
    /// Track when recording is completed successfully
    static func recordingCompleted(scriptId: UUID, duration: Double, wasFirstRecording: Bool = false) {
        shared.track(wasFirstRecording ? "first_recording_completed" : "recording_completed", properties: [
            "script_id": scriptId.uuidString,
            "duration": duration
        ])
    }
    
    /// Track when recording is cancelled/abandoned
    static func recordingCancelled(scriptId: UUID, duration: Double, reason: String = "user_cancelled") {
        shared.track("recording_cancelled", properties: [
            "script_id": scriptId.uuidString,
            "partial_duration": duration,
            "reason": reason
        ])
    }
    
    /// Track when playback starts
    static func playbackStarted(scriptId: UUID, isFirstPlayback: Bool = false) {
        shared.track(isFirstPlayback ? "first_playback_started" : "playback_started", properties: [
            "script_id": scriptId.uuidString
        ])
    }
    
    /// Track when playback completes successfully
    static func playbackCompleted(scriptId: UUID, completionRate: Double, isFirstPlayback: Bool = false) {
        shared.track(isFirstPlayback ? "first_playback_completed" : "playback_completed", properties: [
            "script_id": scriptId.uuidString,
            "completion_rate": completionRate
        ])
    }
    
    /// Track when playback is skipped/stopped early
    static func playbackSkipped(scriptId: UUID, completionRate: Double) {
        shared.track("playback_skipped", properties: [
            "script_id": scriptId.uuidString,
            "completion_rate": completionRate
        ])
    }
    
    /// Track when user completes repetitions (habit formation indicator)
    static func scriptRepeated(scriptId: UUID, completedRepetitions: Int, totalRepetitions: Int) {
        shared.track("script_repeated", properties: [
            "script_id": scriptId.uuidString,
            "completed_reps": completedRepetitions,
            "total_reps": totalRepetitions,
            "completion_rate": Double(completedRepetitions) / Double(totalRepetitions)
        ])
    }
    
    // MARK: - Friction Detection
    
    /// Track when user backgrounds app during critical actions
    static func appBackgroundedDuring(action: String, scriptId: UUID?) {
        var properties: [String: Any] = ["action": action]
        if let scriptId = scriptId {
            properties["script_id"] = scriptId.uuidString
        }
        shared.track("app_backgrounded_during_action", properties: properties)
    }
    
    /// Track permission denials
    static func permissionDenied(permission: String) {
        shared.track("permission_denied", properties: [
            "permission": permission
        ])
    }
    
    /// Track interruption recovery outcomes
    static func interruptionRecovery(scriptId: UUID, action: String, wasSuccessful: Bool) {
        shared.track("interruption_recovery", properties: [
            "script_id": scriptId.uuidString,
            "action": action,
            "successful": wasSuccessful
        ])
    }
    
    // MARK: - Session Tracking
    
    /// Track when user starts a practice session
    static func sessionStarted() {
        shared.track("session_started", properties: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track session duration and outcomes
    static func sessionEnded(duration: TimeInterval, scriptsInteracted: Int, recordingsCompleted: Int) {
        shared.track("session_ended", properties: [
            "duration": duration,
            "scripts_interacted": scriptsInteracted,
            "recordings_completed": recordingsCompleted
        ])
    }
    
    // MARK: - Internal Implementation
    
    private func track(_ event: String, properties: [String: Any] = [:]) {
        let timestamp = Date().timeIntervalSince1970
        let eventData: [String: Any] = [
            "event": event,
            "timestamp": timestamp,
            "properties": properties
        ]
        
        // Store locally for now - could be enhanced later for remote analytics
        storeEventLocally(eventData)
        
        // Debug logging in development
        #if DEBUG
        print("📊 HabitMetrics: \(event) - \(properties)")
        #endif
    }
    
    private func storeEventLocally(_ eventData: [String: Any]) {
        // Simple local storage - append to UserDefaults array
        let key = "habit_metrics_events"
        var events = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        events.append(eventData)
        
        // Keep only last 1000 events to prevent storage bloat
        if events.count > 1000 {
            events = Array(events.suffix(1000))
        }
        
        UserDefaults.standard.set(events, forKey: key)
    }
}

// MARK: - Development Helper Extensions

extension HabitMetrics {
    /// Get stored events for debugging/development
    static func getStoredEvents() -> [[String: Any]] {
        return UserDefaults.standard.array(forKey: "habit_metrics_events") as? [[String: Any]] ?? []
    }
    
    /// Clear all stored events (useful for testing)
    static func clearAllEvents() {
        UserDefaults.standard.removeObject(forKey: "habit_metrics_events")
    }
    
    /// Get basic statistics for development insights
    static func getBasicStats() -> [String: Any] {
        let events = getStoredEvents()
        let eventTypes = events.compactMap { $0["event"] as? String }
        let uniqueEventTypes = Set(eventTypes)
        
        var stats: [String: Any] = [
            "total_events": events.count,
            "unique_event_types": uniqueEventTypes.count,
            "event_type_counts": [:]
        ]
        
        var eventCounts: [String: Int] = [:]
        for eventType in eventTypes {
            eventCounts[eventType] = (eventCounts[eventType] ?? 0) + 1
        }
        stats["event_type_counts"] = eventCounts
        
        return stats
    }
}