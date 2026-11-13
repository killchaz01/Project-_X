import Foundation

enum WorkoutLibrary {
    private typealias E = ExerciseLibrary

    private static func step(_ e: Exercise, _ work: Int, rest: Int = 20) -> WorkoutStep {
        WorkoutStep(exercise: e, workSeconds: work, restSeconds: rest)
    }

    // MARK: Strong Over 50
    static let over50: [Workout] = [
        Workout(id: "o50-foundation", title: "Strength Foundations",
                summary: "Sit-to-stands, wall push-ups and rows for everyday strength.",
                focus: .over50, isMicro: false, rounds: 2,
                steps: [step(E.marching, 60), step(E.sitToStand, 40, rest: 30), step(E.wallPushUp, 40, rest: 30),
                        step(E.bandRow, 40, rest: 30), step(E.heelRaise, 40, rest: 30)]),
        Workout(id: "o50-balance", title: "Steady Balance",
                summary: "Build confidence on your feet and lower your risk of falls.",
                focus: .over50, isMicro: false, rounds: 2,
                steps: [step(E.marching, 45), step(E.balance, 40), step(E.heelRaise, 40),
                        step(E.stepUp, 40, rest: 30), step(E.birdDog, 40)]),
        Workout(id: "o50-legs-back", title: "Strong Legs & Back",
                summary: "Squats, bridges and carries for stairs, gardening and grandkids.",
                focus: .over50, isMicro: false, rounds: 2,
                steps: [step(E.marching, 45), step(E.squat, 40, rest: 30), step(E.gluteBridge, 40, rest: 30),
                        step(E.farmerCarry, 45, rest: 30), step(E.birdDog, 40)])
    ]

    // MARK: Postpartum
    static let postpartum: [Workout] = [
        Workout(id: "pp-reconnect", title: "Week 1: Reconnect",
                summary: "Breathing and pelvic floor basics. Gentle enough for the early weeks once cleared.",
                focus: .postpartum, isMicro: false, rounds: 2,
                steps: [step(E.breathing, 60), step(E.pelvicFloor, 45), step(E.heelSlide, 45), step(E.gluteBridge, 30)]),
        Workout(id: "pp-core-rebuild", title: "Core Rebuild",
                summary: "Deep core and glute work to support lifting your baby.",
                focus: .postpartum, isMicro: false, rounds: 2,
                steps: [step(E.breathing, 45), step(E.gluteBridge, 40), step(E.clam, 45),
                        step(E.birdDog, 40), step(E.pelvicFloor, 40)]),
        Workout(id: "pp-strength", title: "Back to Strength",
                summary: "Full-body strength once your core feels connected and you're pain-free.",
                focus: .postpartum, isMicro: false, rounds: 3,
                steps: [step(E.squat, 40, rest: 25), step(E.wallPushUp, 40, rest: 25),
                        step(E.bandRow, 40, rest: 25), step(E.gluteBridge, 40, rest: 25)])
    ]

    // MARK: Fitness race prep (Hyrox-style hybrid racing)
    static let raceTraining: [Workout] = [
        Workout(id: "race-stations", title: "Station Circuit",
                summary: "Run between functional stations, like race day.",
                focus: .raceTraining, isMicro: false, rounds: 2,
                steps: [step(E.run, 180, rest: 15), step(E.skiPull, 60, rest: 15), step(E.run, 180, rest: 15),
                        step(E.sledPush, 60, rest: 15), step(E.run, 180, rest: 15), step(E.burpeeBroadJump, 60, rest: 60)]),
        Workout(id: "race-compromised", title: "Compromised Running",
                summary: "Practise running on tired legs straight after lunges and wall balls.",
                focus: .raceTraining, isMicro: false, rounds: 3,
                steps: [step(E.lunge, 60, rest: 0), step(E.run, 120, rest: 30),
                        step(E.wallBall, 60, rest: 0), step(E.run, 120, rest: 60)]),
        Workout(id: "race-engine", title: "Engine Builder",
                summary: "Rowing, carries and wall balls for race-day endurance.",
                focus: .raceTraining, isMicro: false, rounds: 3,
                steps: [step(E.row, 120, rest: 20), step(E.farmerCarry, 60, rest: 20),
                        step(E.wallBall, 60, rest: 20), step(E.run, 90, rest: 60)])
    ]

    // MARK: General
    static let general: [Workout] = [
        Workout(id: "gen-total-body", title: "Total Body 20",
                summary: "A balanced full-body session with no equipment.",
                focus: .general, isMicro: false, rounds: 3,
                steps: [step(E.marching, 45), step(E.squat, 40), step(E.wallPushUp, 40),
                        step(E.lunge, 40), step(E.birdDog, 40)])
    ]

    // MARK: Micro-workouts (everyone)
    static let micro: [Workout] = [
        Workout(id: "micro-kettle", title: "Kettle Boil",
                summary: "3 minutes in the kitchen while the kettle boils.",
                focus: nil, isMicro: true, rounds: 1,
                steps: [step(E.heelRaise, 40, rest: 10), step(E.sitToStand, 40, rest: 10), step(E.wallPushUp, 40, rest: 10),
                        step(E.balance, 30, rest: 0)]),
        Workout(id: "micro-wake-up", title: "Morning Wake-Up",
                summary: "4 gentle minutes to get moving.",
                focus: nil, isMicro: true, rounds: 1,
                steps: [step(E.breathing, 45, rest: 10), step(E.marching, 60, rest: 10), step(E.squat, 45, rest: 10),
                        step(E.birdDog, 45, rest: 0)]),
        Workout(id: "micro-desk", title: "Desk Break",
                summary: "Undo sitting in 3 minutes.",
                focus: nil, isMicro: true, rounds: 1,
                steps: [step(E.sitToStand, 45, rest: 10), step(E.bandRow, 45, rest: 10), step(E.heelRaise, 45, rest: 10),
                        step(E.marching, 30, rest: 0)]),
        Workout(id: "micro-power", title: "5-Minute Power",
                summary: "A quick burst to raise your heart rate.",
                focus: nil, isMicro: true, rounds: 2,
                steps: [step(E.squat, 30, rest: 10), step(E.burpeeBroadJump, 30, rest: 10), step(E.lunge, 30, rest: 10),
                        step(E.marching, 30, rest: 10)])
    ]

    static func programs(for focus: FitnessFocus) -> [Workout] {
        switch focus {
        case .over50: over50
        case .postpartum: postpartum
        case .raceTraining: raceTraining
        case .general: general + over50.prefix(1)
        }
    }

    static var all: [Workout] { over50 + postpartum + raceTraining + general + micro }

    static func workout(id: String) -> Workout? { all.first { $0.id == id } }

    /// A different suggestion each day, so the Today screen feels fresh.
    static func suggestion(for focus: FitnessFocus, on date: Date = .now) -> (program: Workout, micro: Workout) {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let programs = programs(for: focus)
        return (programs[day % programs.count], micro[day % micro.count])
    }
}
