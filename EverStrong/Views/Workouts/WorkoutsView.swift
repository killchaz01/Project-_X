import SwiftUI

struct WorkoutsView: View {
    @Bindable var profile: UserProfile
    @State private var browsing: FitnessFocus?

    private var shownFocus: FitnessFocus { browsing ?? profile.focus }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Program", selection: Binding(get: { shownFocus }, set: { browsing = $0 })) {
                        ForEach(FitnessFocus.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .font(.title3)
                } footer: {
                    Text(shownFocus.subtitle)
                }

                if shownFocus == .postpartum {
                    Section { SafetyNote(text: Disclaimers.postpartum) }
                }

                Section(shownFocus == profile.focus ? "Your program" : shownFocus.title) {
                    ForEach(WorkoutLibrary.programs(for: shownFocus)) { workout in
                        NavigationLink(value: workout) { WorkoutRow(workout: workout).padding(.vertical, 6) }
                    }
                }

                Section("Micro-workouts · under 5 minutes") {
                    ForEach(WorkoutLibrary.micro) { workout in
                        NavigationLink(value: workout) { WorkoutRow(workout: workout).padding(.vertical, 6) }
                    }
                }
            }
            .navigationTitle("Workouts")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0, profile: profile) }
        }
    }
}

struct WorkoutDetailView: View {
    let workout: Workout
    @Bindable var profile: UserProfile
    @State private var playing = false

    private var locked: Bool { workout.focus == .postpartum && !profile.postpartumClearanceConfirmed }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(workout.summary).font(.title3)
                HStack(spacing: 16) {
                    Label(TimeFormat.duration(workout.totalSeconds), systemImage: "clock")
                    Label("\(workout.rounds) round\(workout.rounds == 1 ? "" : "s")", systemImage: "repeat")
                }
                .font(.headline).foregroundStyle(.secondary)

                if locked {
                    SafetyNote(text: Disclaimers.postpartum)
                    Toggle("My doctor or midwife has cleared me to exercise", isOn: $profile.postpartumClearanceConfirmed)
                        .font(.title3)
                }

                BigButton(title: "Start workout", symbol: "play.fill", color: locked ? .gray : .accentColor) {
                    playing = true
                }
                .disabled(locked)

                Text("Exercises").font(.title2.bold())
                ForEach(workout.exercises) { exercise in
                    ExerciseCard(exercise: exercise)
                }

                Text(Disclaimers.exercise).font(.footnote).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(workout.title)
        .fullScreenCover(isPresented: $playing) { WorkoutPlayerView(workout: workout) }
    }
}

struct ExerciseCard: View {
    let exercise: Exercise
    var body: some View {
        Card {
            HStack {
                Image(systemName: exercise.symbol).font(.title).foregroundStyle(Color.accentColor).frame(width: 44)
                Text(exercise.name).font(.title3.bold())
                Spacer()
                if exercise.formCheck != nil {
                    Image(systemName: "camera.viewfinder").foregroundStyle(.secondary)
                        .accessibilityLabel("Form check available")
                }
            }
            ForEach(Array(exercise.cues.enumerated()), id: \.offset) { index, cue in
                Text("\(index + 1). \(cue)").font(.body)
            }
            if let easier = exercise.easier {
                Label("Easier: \(easier)", systemImage: "tortoise.fill").font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}
