import Foundation

/// The state of a workout in progress. A plain value type, so the timing logic is unit-testable.
struct WorkoutSession {
    enum Kind: Equatable { case getReady, work, rest }

    struct Phase: Equatable {
        let kind: Kind
        let exercise: Exercise
        let seconds: Int
        let round: Int
    }

    enum Event: Equatable {
        case phaseStarted(Phase)
        case countdown(Int)
        case finished
    }

    let workout: Workout
    let phases: [Phase]
    private(set) var index = 0
    private(set) var remaining: Int
    private(set) var elapsed = 0
    var isPaused = false
    private(set) var isFinished = false

    init(workout: Workout, getReadySeconds: Int = 10) {
        self.workout = workout
        var phases: [Phase] = []
        if let first = workout.steps.first {
            phases.append(Phase(kind: .getReady, exercise: first.exercise, seconds: getReadySeconds, round: 1))
        }
        for round in 1...max(1, workout.rounds) {
            for (i, step) in workout.steps.enumerated() {
                phases.append(Phase(kind: .work, exercise: step.exercise, seconds: step.workSeconds, round: round))
                let isLast = round == workout.rounds && i == workout.steps.count - 1
                if step.restSeconds > 0 && !isLast {
                    let next = workout.steps[(i + 1) % workout.steps.count].exercise
                    phases.append(Phase(kind: .rest, exercise: next, seconds: step.restSeconds, round: round))
                }
            }
        }
        self.phases = phases
        self.remaining = phases.first?.seconds ?? 0
    }

    var current: Phase? { phases.indices.contains(index) ? phases[index] : nil }

    /// The next work phase, to show "Up next".
    var upNext: Phase? {
        phases.dropFirst(index + 1).first { $0.kind == .work }
    }

    var progress: Double {
        guard !phases.isEmpty else { return 1 }
        return Double(index) / Double(phases.count)
    }

    /// Advance one second.
    mutating func tick() -> Event? {
        guard !isPaused, !isFinished else { return nil }
        elapsed += 1
        remaining -= 1
        if remaining <= 0 { return advance() }
        if remaining <= 3 { return .countdown(remaining) }
        return nil
    }

    mutating func skip() -> Event? { advance() }

    mutating func back() -> Event? {
        guard !isFinished else { return nil }
        index = max(0, index - 1)
        remaining = phases[index].seconds
        return .phaseStarted(phases[index])
    }

    private mutating func advance() -> Event? {
        index += 1
        guard let phase = current else {
            isFinished = true
            remaining = 0
            return .finished
        }
        remaining = phase.seconds
        return .phaseStarted(phase)
    }
}
