import Foundation

/// Pure calculations behind the progress screen, so they can be unit-tested.
enum ProgressStats {
    /// Consecutive active days, counting back from today (or from yesterday, if today isn't done yet).
    static func streak(activeDates: [Date], today: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(activeDates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: today)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// The seven days (start of day) of the week containing `today`, in the user's calendar order.
    static func weekDays(containing today: Date = .now, calendar: Calendar = .current) -> [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Which days of the current week have at least one entry.
    static func activeDaysThisWeek(activeDates: [Date], today: Date = .now, calendar: Calendar = .current) -> Set<Date> {
        let week = Set(weekDays(containing: today, calendar: calendar))
        return Set(activeDates.map { calendar.startOfDay(for: $0) }).intersection(week)
    }

    struct MedicationSummary {
        let createdAt: Date
        let minutesOfDay: [Int]
        let takenDates: [Date]
    }

    /// Share of scheduled doses marked taken over the last `days` days (0–1), or nil if none were due.
    /// Doses later today that aren't due yet are not counted against the user.
    static func adherence(_ medications: [MedicationSummary], days: Int = 7,
                          now: Date = .now, calendar: Calendar = .current) -> Double? {
        let today = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return nil }
        let nowMinute = TimeFormat.minuteOfDay(from: now, calendar: calendar)
        var expected = 0
        var taken = 0
        for med in medications {
            let firstDay = max(windowStart, calendar.startOfDay(for: med.createdAt))
            var day = firstDay
            var expectedForMed = 0
            while day <= today {
                if day == today {
                    expectedForMed += med.minutesOfDay.filter { $0 <= nowMinute }.count
                } else {
                    expectedForMed += med.minutesOfDay.count
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            let takenForMed = med.takenDates.filter { $0 >= firstDay && $0 <= now }.count
            expected += expectedForMed
            taken += min(takenForMed, expectedForMed)
        }
        return expected == 0 ? nil : Double(taken) / Double(expected)
    }
}
