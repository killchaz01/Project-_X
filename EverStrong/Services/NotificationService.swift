import Foundation
import UserNotifications

/// Local notifications only — nothing is sent to a server.
enum NotificationService {
    private static var center: UNUserNotificationCenter { .current() }
    static let workoutReminderID = "daily-workout-reminder"

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// One gentle reminder a day to move.
    static func scheduleDailyWorkoutReminder(hour: Int, minute: Int, name: String) {
        center.removePendingNotificationRequests(withIdentifiers: [workoutReminderID])
        let content = UNMutableNotificationContent()
        content.title = name.isEmpty ? "Time to move" : "Time to move, \(name)"
        content.body = "Even 3 minutes counts. Tap to start today's workout."
        content.sound = .default
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: workoutReminderID, content: content, trigger: trigger))
    }

    static func cancelDailyWorkoutReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [workoutReminderID])
    }
}
