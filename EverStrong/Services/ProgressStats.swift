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
}
