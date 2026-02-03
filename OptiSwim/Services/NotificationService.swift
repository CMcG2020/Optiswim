import Foundation
import UserNotifications

// MARK: - Notification Service

final class NotificationService: @unchecked Sendable {
    static let shared = NotificationService()
    
    private let center = UNUserNotificationCenter.current()
    
    private init() {}
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }
    
    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - Schedule Daily Alert
    
    func scheduleDailyAlert(at hour: Int, minute: Int) async {
        // Remove existing daily alerts
        center.removePendingNotificationRequests(withIdentifiers: ["daily-conditions"])
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Swim Conditions"
        content.body = "Check today's swimming conditions at your favorite spots!"
        content.sound = .default
        content.categoryIdentifier = "DAILY_CONDITIONS"
        
        let request = UNNotificationRequest(
            identifier: "daily-conditions",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule daily alert: \(error)")
        }
    }
    
    func cancelDailyAlert() {
        center.removePendingNotificationRequests(withIdentifiers: ["daily-conditions"])
    }
    
    // MARK: - Optimal Window Alert
    
    func sendOptimalWindowAlert(window: TimeWindow, locationName: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Perfect Swimming Conditions! 🌊"
        content.body = "Optimal window at \(locationName): \(window.timeRangeString). Score: \(Int(window.averageScore))/100"
        content.sound = .default
        content.categoryIdentifier = "OPTIMAL_WINDOW"
        
        let request = UNNotificationRequest(
            identifier: "optimal-\(UUID().uuidString)",
            content: content,
            trigger: nil // Immediate
        )
        
        do {
            try await center.add(request)
        } catch {
            print("Failed to send optimal window alert: \(error)")
        }
    }
    
    // MARK: - Safety Alert
    
    func sendSafetyAlert(warnings: [SafetyWarning], locationName: String) async {
        guard !warnings.isEmpty else { return }
        
        let criticalWarnings = warnings.filter { $0.severity == .critical }
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Swimming Safety Alert"
        content.body = criticalWarnings.isEmpty
            ? "Conditions at \(locationName) require caution: \(warnings.first?.rawValue ?? "")"
            : "Dangerous conditions at \(locationName): \(criticalWarnings.first?.rawValue ?? "")"
        content.sound = .defaultCritical
        content.categoryIdentifier = "SAFETY_ALERT"
        content.interruptionLevel = .timeSensitive
        
        let request = UNNotificationRequest(
            identifier: "safety-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await center.add(request)
        } catch {
            print("Failed to send safety alert: \(error)")
        }
    }
    
    // MARK: - Location Update Alert
    
    func sendLocationUpdateAlert(locationName: String, score: SwimScore) async {
        let content = UNMutableNotificationContent()
        content.title = "\(locationName) Update"
        content.body = "Current score: \(score.displayValue)/100 - \(score.rating.message)"
        content.sound = .default
        content.categoryIdentifier = "LOCATION_UPDATE"
        
        let request = UNNotificationRequest(
            identifier: "location-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await center.add(request)
        } catch {
            print("Failed to send location update: \(error)")
        }
    }
    
    // MARK: - Clear All
    
    func clearAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
