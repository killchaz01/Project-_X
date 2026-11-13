import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String
    var focusRaw: String
    var createdAt: Date
    var workoutReminderEnabled: Bool
    var workoutReminderHour: Int
    var workoutReminderMinute: Int
    /// The user has confirmed a doctor or midwife has cleared them to exercise after birth.
    var postpartumClearanceConfirmed: Bool

    var focus: FitnessFocus {
        get { FitnessFocus(rawValue: focusRaw) ?? .general }
        set { focusRaw = newValue.rawValue }
    }

    init(name: String, focus: FitnessFocus) {
        self.name = name
        self.focusRaw = focus.rawValue
        self.createdAt = .now
        self.workoutReminderEnabled = true
        self.workoutReminderHour = 9
        self.workoutReminderMinute = 0
        self.postpartumClearanceConfirmed = false
    }
}

@Model
final class WorkoutLog {
    var date: Date
    var workoutID: String
    var title: String
    var durationSeconds: Int

    init(date: Date = .now, workoutID: String, title: String, durationSeconds: Int) {
        self.date = date
        self.workoutID = workoutID
        self.title = title
        self.durationSeconds = durationSeconds
    }
}

enum TimeFormat {
    /// "8:30 AM" style text for minutes after midnight, using the user's locale.
    static func string(minuteOfDay: Int) -> String {
        var comps = DateComponents()
        comps.hour = minuteOfDay / 60
        comps.minute = minuteOfDay % 60
        let date = Calendar.current.date(from: comps) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func minuteOfDay(from date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func date(minuteOfDay: Int, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: minuteOfDay / 60, minute: minuteOfDay % 60, second: 0, of: .now) ?? .now
    }

    /// "4 min" / "1 min 30 s"
    static func duration(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        if m == 0 { return "\(s) s" }
        return s == 0 ? "\(m) min" : "\(m) min \(s) s"
    }
}
