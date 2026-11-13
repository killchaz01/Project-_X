import SwiftUI
import SwiftData

struct TodayView: View {
    @Bindable var profile: UserProfile
    @Query(sort: \WorkoutLog.date, order: .reverse) private var logs: [WorkoutLog]

    @AppStorage(AppSettings.weeklyGoal) private var weeklyGoal = 3

    @State private var showingSettings = false
    @State private var playing: Workout?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(greeting).font(.largeTitle.bold())
                    Text(Date.now.formatted(date: .complete, time: .omitted))
                        .font(.title3).foregroundStyle(.secondary)

                    workoutCard
                    progressCard
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape.fill").font(.title2)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView(profile: profile) }
            .fullScreenCover(item: $playing) { WorkoutPlayerView(workout: $0) }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
        return "\(part), \(profile.name)"
    }

    // MARK: Workouts

    private var workoutCard: some View {
        let suggestion = WorkoutLibrary.suggestion(for: profile.focus)
        let doneToday = logs.contains { Calendar.current.isDateInToday($0.date) }
        return Card {
            HStack {
                Label("Today's movement", systemImage: profile.focus.symbol).font(.title2.bold())
                Spacer()
                if doneToday { Image(systemName: "star.fill").foregroundStyle(.yellow).accessibilityLabel("Workout done today") }
            }
            WorkoutRow(workout: suggestion.micro)
            BigButton(title: "Start \(suggestion.micro.title)", symbol: "play.fill") { playing = suggestion.micro }
            Divider()
            WorkoutRow(workout: suggestion.program)
            BigButton(title: "Start \(suggestion.program.title)", symbol: "play.fill",
                      color: Color(.tertiarySystemFill), foreground: .primary) {
                playing = suggestion.program
            }
            .disabled(suggestion.program.focus == .postpartum && !profile.postpartumClearanceConfirmed)
            if suggestion.program.focus == .postpartum && !profile.postpartumClearanceConfirmed {
                Text("Confirm your medical clearance in Settings to unlock postpartum workouts.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Progress

    private var progressCard: some View {
        let active = ProgressStats.activeDaysThisWeek(activeDates: logs.map(\.date))
        let streak = ProgressStats.streak(activeDates: logs.map(\.date))
        return NavigationLink {
            ProgressScreen()
        } label: {
            Card {
                HStack {
                    Label("This week", systemImage: "chart.bar.fill").font(.title2.bold())
                    Spacer()
                    Image(systemName: "chevron.right").font(.headline).foregroundStyle(.secondary)
                }
                WeekStrip(activeDays: active)
                Text("\(active.count) of \(weeklyGoal) active days" + (streak > 1 ? " · \(streak)-day streak" : ""))
                    .font(.title3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens your progress")
    }
}

struct WorkoutRow: View {
    let workout: Workout
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.title).font(.title3.bold())
            Text(workout.summary).font(.body).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label(TimeFormat.duration(workout.totalSeconds), systemImage: "clock")
                if workout.hasFormCheck { Label("Form check", systemImage: "camera.viewfinder") }
            }
            .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
