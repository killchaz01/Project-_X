import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String
    var focusRaw: String
    var createdAt: Date
    var checkInReminderEnabled: Bool
    var checkInReminderHour: Int
    var checkInReminderMinute: Int
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
        self.checkInReminderEnabled = true
        self.checkInReminderHour = 9
        self.checkInReminderMinute = 0
        self.postpartumClearanceConfirmed = false
    }
}

@Model
final class Medication {
    var id: UUID
    var name: String
    var dosage: String
    var notes: String
    /// Reminder times as minutes after midnight, e.g. 8:30 am = 510.
    var minutesOfDay: [Int]
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \MedicationDose.medication)
    var doses: [MedicationDose] = []

    init(name: String, dosage: String, notes: String = "", minutesOfDay: [Int]) {
        self.id = UUID()
        self.name = name
        self.dosage = dosage
        self.notes = notes
        self.minutesOfDay = minutesOfDay.sorted()
        self.createdAt = .now
    }

    /// Whether the dose scheduled at `minute` has been marked taken on `day`.
    func isTaken(minute: Int, on day: Date = .now, calendar: Calendar = .current) -> Bool {
        doses.contains { $0.scheduledMinute == minute && calendar.isDate($0.takenAt, inSameDayAs: day) }
    }
}

@Model
final class MedicationDose {
    var takenAt: Date
    var scheduledMinute: Int
    var medication: Medication?

    init(takenAt: Date = .now, scheduledMinute: Int, medication: Medication) {
        self.takenAt = takenAt
        self.scheduledMinute = scheduledMinute
        self.medication = medication
    }
}

@Model
final class FamilyContact {
    var id: UUID
    var name: String
    var relationship: String
    var phone: String
    @Attribute(.externalStorage) var photoData: Data?
    var receivesCheckIns: Bool
    var sortOrder: Int

    init(name: String, relationship: String, phone: String, photoData: Data? = nil,
         receivesCheckIns: Bool = true, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.relationship = relationship
        self.phone = phone
        self.photoData = photoData
        self.receivesCheckIns = receivesCheckIns
        self.sortOrder = sortOrder
    }

    /// Phone number reduced to digits and a leading "+", safe to put in a tel: URL.
    var dialableNumber: String {
        PhoneNumber.dialable(phone)
    }
}

@Model
final class CheckIn {
    var date: Date
    /// "ok" or "needsCall"
    var status: String

    init(date: Date = .now, status: String) {
        self.date = date
        self.status = status
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

enum PhoneNumber {
    static func dialable(_ raw: String) -> String {
        var result = ""
        for (index, ch) in raw.trimmingCharacters(in: .whitespaces).enumerated() {
            if ch.isASCII && ch.isNumber { result.append(ch) }
            else if ch == "+" && index == 0 { result.append(ch) }
        }
        return result
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
