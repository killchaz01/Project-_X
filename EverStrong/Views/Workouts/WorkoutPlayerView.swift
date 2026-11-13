import SwiftUI
import SwiftData

struct WorkoutPlayerView: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var session: WorkoutSession
    @State private var confirmExit = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(workout: Workout) {
        self.workout = workout
        _session = State(initialValue: WorkoutSession(workout: workout))
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button { confirmExit = true } label: {
                    Image(systemName: "xmark.circle.fill").font(.largeTitle).foregroundStyle(.secondary)
                }
                .accessibilityLabel("End workout")
                Spacer()
                Text(workout.title).font(.headline)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            ProgressView(value: session.progress).tint(.accentColor)

            if session.isFinished {
                finishedView
            } else if let phase = session.current {
                phaseView(phase)
            }
        }
        .padding(20)
        .background(background.ignoresSafeArea())
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if let first = session.current { announce(first) }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            SpeechCoach.shared.stop()
        }
        .onReceive(ticker) { _ in handle(session.tick()) }
        .confirmationDialog("End this workout?", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("End workout", role: .destructive) { dismiss() }
            Button("Keep going", role: .cancel) {}
        }
    }

    private var background: Color {
        switch session.current?.kind {
        case .work?: Color.accentColor.opacity(0.15)
        case .rest?: Color.blue.opacity(0.12)
        default: Color(.systemBackground)
        }
    }

    @ViewBuilder
    private func phaseView(_ phase: WorkoutSession.Phase) -> some View {
        VStack(spacing: 16) {
            Text(label(for: phase)).font(.title2.bold()).foregroundStyle(.secondary)
            Image(systemName: phase.kind == .rest ? "pause.circle" : phase.exercise.symbol)
                .font(.system(size: 80)).foregroundStyle(Color.accentColor)
            Text(phase.exercise.name).font(.largeTitle.bold()).multilineTextAlignment(.center)

            Text("\(session.remaining)")
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .accessibilityLabel("\(session.remaining) seconds left")

            if phase.kind == .work, let cue = phase.exercise.cues.first {
                Text(cue).font(.title3).multilineTextAlignment(.center)
            }
            if phase.kind == .work, let easier = phase.exercise.easier {
                Label("Easier: \(easier)", systemImage: "tortoise.fill")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            if phase.kind != .work, let next = session.upNext {
                Text("Up next: \(next.exercise.name)").font(.title3)
            }
            Spacer()
            HStack(spacing: 14) {
                controlButton("Back", symbol: "backward.fill") { handle(session.back()) }
                controlButton(session.isPaused ? "Resume" : "Pause",
                              symbol: session.isPaused ? "play.fill" : "pause.fill", prominent: true) {
                    session.isPaused.toggle()
                    SpeechCoach.shared.say(session.isPaused ? "Paused" : "Let's go", interrupt: true)
                }
                controlButton("Skip", symbol: "forward.fill") { handle(session.skip()) }
            }
        }
    }

    private var finishedView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "star.circle.fill").font(.system(size: 120)).foregroundStyle(.yellow)
            Text("Well done!").font(.largeTitle.bold())
            Text("You moved for \(TimeFormat.duration(session.elapsed)).").font(.title2)
            Spacer()
            BigButton(title: "Finish", symbol: "checkmark") { dismiss() }
        }
    }

    private func controlButton(_ title: String, symbol: String, prominent: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.title)
                Text(title).font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(prominent ? Color.accentColor : Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableStyle())
    }

    private func label(for phase: WorkoutSession.Phase) -> String {
        switch phase.kind {
        case .getReady: "Get ready"
        case .rest: "Rest"
        case .work: workout.rounds > 1 ? "Round \(phase.round) of \(workout.rounds)" : "Go"
        }
    }

    private func handle(_ event: WorkoutSession.Event?) {
        switch event {
        case .phaseStarted(let phase)?: announce(phase)
        case .countdown(let n)?: SpeechCoach.shared.say("\(n)")
        case .finished?:
            SpeechCoach.shared.say("Workout complete. Well done!", interrupt: true)
            context.insert(WorkoutLog(workoutID: workout.id, title: workout.title, durationSeconds: session.elapsed))
            try? context.save()
        case nil: break
        }
    }

    private func announce(_ phase: WorkoutSession.Phase) {
        switch phase.kind {
        case .getReady: SpeechCoach.shared.say("Get ready. First up, \(phase.exercise.name).", interrupt: true)
        case .rest: SpeechCoach.shared.say("Rest. Next, \(phase.exercise.name).", interrupt: true)
        case .work:
            let cue = phase.exercise.cues.first ?? ""
            SpeechCoach.shared.say("\(phase.exercise.name). \(cue)", interrupt: true)
        }
    }
}
