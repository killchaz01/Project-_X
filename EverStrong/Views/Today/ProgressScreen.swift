import SwiftUI
import SwiftData

/// Seven circles, one per day of this week. Filled means the user moved that day.
struct WeekStrip: View {
    let activeDays: Set<Date>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ProgressStats.weekDays(), id: \.self) { day in
                let active = activeDays.contains(day)
                let isToday = Calendar.current.isDateInToday(day)
                VStack(spacing: 6) {
                    Text(day.formatted(.dateTime.weekday(.narrow))).font(.subheadline.bold())
                        .foregroundStyle(isToday ? Color.accentColor : Color.secondary)
                    ZStack {
                        Circle().fill(active ? Color.accentColor : Color(.tertiarySystemFill))
                        if active { Image(systemName: "checkmark").font(.headline).foregroundStyle(.white) }
                    }
                    .frame(width: 38, height: 38)
                    .overlay { if isToday { Circle().stroke(Color.accentColor, lineWidth: 2).padding(-3) } }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(activeDays.count) active day\(activeDays.count == 1 ? "" : "s") this week")
    }
}

struct ProgressScreen: View {
    @Query(sort: \WorkoutLog.date, order: .reverse) private var logs: [WorkoutLog]
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Query private var medications: [Medication]
    @AppStorage(AppSettings.weeklyGoal) private var weeklyGoal = 3

    private var workoutDates: [Date] { logs.map(\.date) }
    private var activeThisWeek: Set<Date> { ProgressStats.activeDaysThisWeek(activeDates: workoutDates) }

    private var minutesThisWeek: Int {
        let week = Set(ProgressStats.weekDays())
        return logs.filter { week.contains(Calendar.current.startOfDay(for: $0.date)) }
            .reduce(0) { $0 + $1.durationSeconds } / 60
    }

    private var adherence: Double? {
        ProgressStats.adherence(medications.map {
            ProgressStats.MedicationSummary(createdAt: $0.createdAt, minutesOfDay: $0.minutesOfDay, takenDates: $0.doses.map(\.takenAt))
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Card {
                    Label("This week", systemImage: "calendar").font(.title2.bold())
                    WeekStrip(activeDays: activeThisWeek)
                    let done = activeThisWeek.count
                    Text(done >= weeklyGoal ? "Goal reached! \(done) active days." : "\(done) of \(weeklyGoal) active days")
                        .font(.title3.bold())
                        .foregroundStyle(done >= weeklyGoal ? Color.green : Color.primary)
                    ProgressView(value: Double(min(done, weeklyGoal)), total: Double(weeklyGoal)).tint(.accentColor)
                    Stepper("Weekly goal: \(weeklyGoal) day\(weeklyGoal == 1 ? "" : "s")", value: $weeklyGoal, in: 1...7)
                        .font(.title3)
                }

                HStack(spacing: 16) {
                    StatTile(value: "\(ProgressStats.streak(activeDates: workoutDates))", label: "day streak", symbol: "flame.fill", color: .orange)
                    StatTile(value: "\(minutesThisWeek)", label: "minutes this week", symbol: "clock.fill", color: .accentColor)
                }
                HStack(spacing: 16) {
                    StatTile(value: "\(logs.count)", label: "workouts done", symbol: "star.fill", color: .yellow)
                    StatTile(value: "\(ProgressStats.streak(activeDates: checkIns.map(\.date)))", label: "check-in streak", symbol: "hand.wave.fill", color: .green)
                }

                if let adherence {
                    Card {
                        Label("Medicines, last 7 days", systemImage: "pills.fill").font(.title2.bold())
                        Text("\(Int((adherence * 100).rounded()))% taken").font(.title.bold())
                        ProgressView(value: adherence).tint(adherence >= 0.9 ? .green : .orange)
                        Text("Based on the doses you marked as taken.").font(.callout).foregroundStyle(.secondary)
                    }
                }

                Card {
                    Label("Recent workouts", systemImage: "list.bullet").font(.title2.bold())
                    if logs.isEmpty {
                        Text("Your finished workouts will show up here.").font(.title3).foregroundStyle(.secondary)
                    }
                    ForEach(logs.prefix(10)) { log in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(log.title).font(.title3.bold())
                                Text(log.date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(TimeFormat.duration(log.durationSeconds)).font(.headline)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("My Progress")
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).font(.title).foregroundStyle(color)
            Text(value).font(.system(size: 44, weight: .heavy, design: .rounded)).monospacedDigit()
            Text(label).font(.headline).foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}
