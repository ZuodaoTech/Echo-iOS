import Foundation
import UserNotifications
import CoreData

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification permission error: \(error)")
                }
                completion(granted)
            }
        }
    }
    
    func checkNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }
    
    // MARK: - Scheduling
    
    func scheduleNotifications(for script: SelftalkScript) {
        // First cancel existing notifications for this script
        cancelNotifications(for: script)
        
        guard script.notificationEnabled else { return }
        
        // Request permission if needed
        checkNotificationPermission { [weak self] granted in
            guard granted else {
                self?.requestNotificationPermission { granted in
                    if granted {
                        self?.scheduleNotificationsInternal(for: script)
                    }
                }
                return
            }
            self?.scheduleNotificationsInternal(for: script)
        }
    }
    
    private func scheduleNotificationsInternal(for script: SelftalkScript) {
        let frequency = script.notificationFrequency ?? "medium"
        let scriptId = script.id.uuidString
        
        // Calculate notification times based on frequency
        let notificationTimes = calculateNotificationTimes(frequency: frequency)
        
        // Schedule notifications for the next 7 days
        for dayOffset in 0..<7 {
            for time in notificationTimes {
                guard let scheduledDate = calculateNextNotificationDate(time: time, dayOffset: dayOffset) else { continue }
                
                let content = UNMutableNotificationContent()
                content.title = "Time for Self-Talk"
                content.body = String(script.scriptText.prefix(100))
                content.sound = .default
                content.categoryIdentifier = "SELFTALK_REMINDER"
                content.userInfo = ["scriptId": scriptId]
                
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledDate),
                    repeats: false
                )
                
                let identifier = "\(scriptId)_\(dayOffset)_\(time.hour)_\(time.minute)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Failed to schedule notification: \(error)")
                    }
                }
            }
        }
    }
    
    func cancelNotifications(for script: SelftalkScript) {
        let scriptId = script.id.uuidString
        
        // Get all pending notification identifiers
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests
                .filter { $0.identifier.hasPrefix(scriptId) }
                .map { $0.identifier }
            
            if !identifiersToRemove.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
                print("Cancelled \(identifiersToRemove.count) notifications for script")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private struct NotificationTime {
        let hour: Int
        let minute: Int
    }
    
    private func calculateNotificationTimes(frequency: String) -> [NotificationTime] {
        switch frequency {
        case "high":
            // 1-2 times per hour during daytime (8 AM - 9 PM)
            return [
                NotificationTime(hour: 9, minute: 0),
                NotificationTime(hour: 10, minute: 30),
                NotificationTime(hour: 12, minute: 0),
                NotificationTime(hour: 13, minute: 30),
                NotificationTime(hour: 15, minute: 0),
                NotificationTime(hour: 16, minute: 30),
                NotificationTime(hour: 18, minute: 0),
                NotificationTime(hour: 19, minute: 30),
                NotificationTime(hour: 20, minute: 30)
            ]
        case "low":
            // 1-2 times per day
            return [
                NotificationTime(hour: 10, minute: 0),
                NotificationTime(hour: 19, minute: 0)
            ]
        default: // medium
            // Every 2 hours during daytime
            return [
                NotificationTime(hour: 9, minute: 0),
                NotificationTime(hour: 11, minute: 0),
                NotificationTime(hour: 13, minute: 0),
                NotificationTime(hour: 15, minute: 0),
                NotificationTime(hour: 17, minute: 0),
                NotificationTime(hour: 19, minute: 0)
            ]
        }
    }
    
    private func calculateNextNotificationDate(time: NotificationTime, dayOffset: Int) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        guard var components = calendar.dateComponents([.year, .month, .day], from: now) as DateComponents? else {
            return nil
        }
        
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0
        
        guard var date = calendar.date(from: components) else { return nil }
        
        // Add day offset
        if dayOffset > 0 {
            guard let offsetDate = calendar.date(byAdding: .day, value: dayOffset, to: date) else { return nil }
            date = offsetDate
        }
        
        // Only return future dates
        return date > now ? date : nil
    }
    
    // MARK: - Notification Limit Management
    
    func enforceNotificationLimit(context: NSManagedObjectContext, excludingScript: SelftalkScript? = nil) {
        let request: NSFetchRequest<SelftalkScript> = SelftalkScript.fetchRequest()
        
        if let excludingScript = excludingScript {
            request.predicate = NSPredicate(format: "notificationEnabled == YES AND id != %@", excludingScript.id as CVarArg)
        } else {
            request.predicate = NSPredicate(format: "notificationEnabled == YES")
        }
        
        request.sortDescriptors = [NSSortDescriptor(key: "notificationEnabledAt", ascending: true)]
        
        do {
            let scriptsWithNotifications = try context.fetch(request)
            
            // Keep only the 3 most recent, disable others
            if scriptsWithNotifications.count > 3 {
                for i in 0..<(scriptsWithNotifications.count - 3) {
                    let script = scriptsWithNotifications[i]
                    script.notificationEnabled = false
                    script.notificationEnabledAt = nil
                    cancelNotifications(for: script)
                    print("Disabled notifications for script due to limit: \(script.scriptText.prefix(20))...")
                }
                
                try context.save()
            }
        } catch {
            print("Failed to enforce notification limit: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        if let scriptId = response.notification.request.content.userInfo["scriptId"] as? String {
            // Could navigate to the script or play it
            print("User tapped notification for script: \(scriptId)")
        }
        completionHandler()
    }
}