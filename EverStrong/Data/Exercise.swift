import Foundation

/// Which on-device form check (if any) can analyse an exercise.
enum FormCheckKind: String, Hashable, CaseIterable, Identifiable {
    /// Any squatting pattern: bodyweight squat, chair sit-to-stand, wall-ball squat.
    case squat
    var id: String { rawValue }
}

struct Exercise: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    /// Short coaching cues, read aloud and shown on screen.
    let cues: [String]
    /// A gentler version for low-energy days or limited mobility.
    let easier: String?
    let formCheck: FormCheckKind?

    init(_ id: String, _ name: String, symbol: String, cues: [String],
         easier: String? = nil, formCheck: FormCheckKind? = nil) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.cues = cues
        self.easier = easier
        self.formCheck = formCheck
    }
}

struct WorkoutStep: Hashable {
    let exercise: Exercise
    let workSeconds: Int
    let restSeconds: Int
}

struct Workout: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    /// nil means it suits everyone (micro-workouts).
    let focus: FitnessFocus?
    let isMicro: Bool
    let rounds: Int
    let steps: [WorkoutStep]

    var totalSeconds: Int {
        rounds * steps.reduce(0) { $0 + $1.workSeconds + $1.restSeconds }
    }

    var exercises: [Exercise] {
        var seen = Set<String>()
        return steps.map(\.exercise).filter { seen.insert($0.id).inserted }
    }

    var hasFormCheck: Bool { exercises.contains { $0.formCheck != nil } }
}
