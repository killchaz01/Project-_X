import Foundation

/// Which on-device form check (if any) can analyse an exercise.
enum FormCheckKind: String, Hashable, CaseIterable, Identifiable {
    /// Any squatting pattern: bodyweight squat, chair sit-to-stand, wall-ball squat.
    case squat
    case lunge
    /// Wall or floor push-ups, seen from the side.
    case pushUp
    /// Standing on one leg: times how long the foot stays off the floor.
    case balance

    var id: String { rawValue }

    /// What the big number on screen counts.
    var countLabel: String { self == .balance ? "sec best" : "reps" }

    var startHint: String {
        switch self {
        case .squat, .lunge: "Stand side-on to the camera so your whole body is in view."
        case .pushUp: "Turn side-on to the camera so it can see your shoulder, elbow and wrist."
        case .balance: "Face the camera, hold on to something steady, then lift one foot."
        }
    }

    var notVisibleHint: String {
        switch self {
        case .pushUp: "Move so your shoulder, elbow and wrist are all on screen."
        default: "Step back until your head, hips, knees and feet are all on screen."
        }
    }

    /// (SF Symbol, instruction) pairs shown before starting.
    var setupSteps: [(symbol: String, text: String)] {
        switch self {
        case .squat, .lunge:
            [("iphone", "Lean your phone upright against something steady, at about hip height."),
             ("arrow.left.and.right", "Stand 2 to 3 metres (6 to 10 feet) away, side-on to the phone."),
             ("person.fill.viewfinder", "Make sure your head and feet are both on screen."),
             ("chair", "Clear the space around you and keep a chair nearby.")]
        case .pushUp:
            [("iphone", "Lean your phone upright against something steady, at about chest height."),
             ("arrow.left.and.right", "Stand 2 to 3 metres (6 to 10 feet) away, side-on, facing a wall."),
             ("person.fill.viewfinder", "Make sure the phone can see your arm from shoulder to wrist."),
             ("hand.raised", "For floor push-ups, put the phone low down instead.")]
        case .balance:
            [("iphone", "Lean your phone upright against something steady, at about hip height."),
             ("arrow.up.and.down", "Stand 2 to 3 metres (6 to 10 feet) away, facing the phone."),
             ("person.fill.viewfinder", "Make sure both feet are on screen."),
             ("hand.raised", "Stand next to a counter or sturdy chair you can hold.")]
        }
    }
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
