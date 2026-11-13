import Foundation
import UserNotifications

/// Local notifications only — nothing is sent to a server.
enum NotificationService {
    private static var center: UNUserNotificationCenter { .current() }
    static let checkInID = "daily-check-in"

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    private static func identifiers(for medID: UUID, minutes: [Int]) -> [String] {
        minutes.map { "med-\(medID.uuidString)-\($0)" }
    }

    /// Replace all reminders for a medication with one daily reminder per time.
    static func schedule(medicationID: UUID, name: String, dosage: String, minutes: [Int], previousMinutes: [Int] = []) {
        cancel(medicationID: medicationID, minutes: previousMinutes + minutes)
        for minute in minutes {
            let content = UNMutableNotificationContent()
            content.title = "Time for \(name)"
            content.body = dosage.isEmpty ? "Open EverStrong to mark it as taken." : "\(dosage). Open EverStrong to mark it as taken."
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            var comps = DateComponents()
            comps.hour = minute / 60
            comps.minute = minute % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: "med-\(medicationID.uuidString)-\(minute)",
                                                content: content, trigger: trigger)
            center.add(request)
        }
    }

    static func cancel(medicationID: UUID, minutes: [Int]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers(for: medicationID, minutes: minutes))
    }

    static func scheduleDailyCheckIn(hour: Int, minute: Int, name: String) {
        center.removePendingNotificationRequests(withIdentifiers: [checkInID])
        let content = UNMutableNotificationContent()
        content.title = "Good morning\(name.isEmpty ? "" : ", \(name)")"
        content.body = "Tap to let your family know you're OK today."
        content.sound = .default
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: checkInID, content: content, trigger: trigger))
    }

    static func cancelDailyCheckIn() {
        center.removePendingNotificationRequests(withIdentifiers: [checkInID])
    }
}
