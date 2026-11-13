import SwiftUI
import SwiftData

struct TodayView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Query(sort: \Medication.name) private var medications: [Medication]
    @Query(sort: \FamilyContact.sortOrder) private var family: [FamilyContact]
    @Query(sort: \WorkoutLog.date, order: .reverse) private var logs: [WorkoutLog]

    @State private var showingCheckIn = false
    @State private var showingSettings = false
    @State private var playing: Workout?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(greeting).font(.largeTitle.bold())
                    Text(Date.now.formatted(date: .complete, time: .omitted))
                        .font(.title3).foregroundStyle(.secondary)

                    checkInCard
                    medicineCard
                    workoutCard
                    if !family.isEmpty { quickCallCard }
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
            .sheet(isPresented: $showingCheckIn) { CheckInView(profile: profile) }
            .sheet(isPresented: $showingSettings) { SettingsView(profile: profile) }
            .fullScreenCover(item: $playing) { WorkoutPlayerView(workout: $0) }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
        return "\(part), \(profile.name)"
    }

    // MARK: Check-in

    private var todaysCheckIn: CheckIn? {
        checkIns.first { Calendar.current.isDateInToday($0.date) }
    }

    @ViewBuilder private var checkInCard: some View {
        if let done = todaysCheckIn {
            Card {
                Label {
                    VStack(alignment: .leading) {
                        Text("You checked in today").font(.title3.bold())
                        Text("at \(done.date.formatted(date: .omitted, time: .shortened))").foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(.green)
                }
                Button("Send another message") { showingCheckIn = true }.font(.body)
            }
        } else {
            BigButton(title: "I'm OK today", symbol: "hand.wave.fill", color: .green) { showingCheckIn = true }
                .accessibilityHint("Lets your family know you're OK")
        }
    }

    // MARK: Medicines

    private struct DueDose: Identifiable {
        let medication: Medication
        let minute: Int
        var id: String { "\(medication.id)-\(minute)" }
    }

    /// Doses not yet taken today, earliest first.
    private var dueDoses: [DueDose] {
        medications
            .flatMap { med in med.minutesOfDay.map { DueDose(medication: med, minute: $0) } }
            .filter { !$0.medication.isTaken(minute: $0.minute) }
            .sorted { $0.minute < $1.minute }
    }

    @ViewBuilder private var medicineCard: some View {
        if !medications.isEmpty {
            Card {
                Label("Medicines", systemImage: "pills.fill").font(.title2.bold())
                if let next = dueDoses.first {
                    let isLate = next.minute <= TimeFormat.minuteOfDay(from: .now)
                    Text("\(next.medication.name) \(next.medication.dosage)").font(.title3.bold())
                    Text(isLate ? "Due now (\(TimeFormat.string(minuteOfDay: next.minute)))"
                                : "Next at \(TimeFormat.string(minuteOfDay: next.minute))")
                        .foregroundStyle(isLate ? Color.orange : Color.secondary)
                    BigButton(title: "I've taken it", symbol: "checkmark.circle.fill") {
                        context.insert(MedicationDose(scheduledMinute: next.minute, medication: next.medication))
                        try? context.save()
                    }
                } else {
                    Label("All done for today", systemImage: "checkmark.circle.fill")
                        .font(.title3).foregroundStyle(.green)
                }
            }
        }
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

    // MARK: Family

    private var quickCallCard: some View {
        Card {
            Label("Call family", systemImage: "phone.fill").font(.title2.bold())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(family.prefix(6)) { person in
                        Button {
                            if let url = URL(string: "tel://\(person.dialableNumber)") { openURL(url) }
                        } label: {
                            VStack {
                                ContactAvatar(name: person.name, photoData: person.photoData, size: 88)
                                Text(person.name).font(.headline).foregroundStyle(.primary)
                            }
                        }
                        .accessibilityLabel("Call \(person.name)")
                    }
                }
            }
        }
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
