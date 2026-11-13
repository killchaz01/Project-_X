import Foundation

/// Every exercise in the app. Kept as plain data so it is easy to review and extend.
enum ExerciseLibrary {
    // MARK: Strength & balance (great for over 50, useful for everyone)
    static let sitToStand = Exercise("sit-to-stand", "Chair Sit-to-Stand", symbol: "chair",
        cues: ["Sit near the front of a sturdy chair, feet hip-width apart.",
               "Lean forward slightly and stand up tall.",
               "Sit back down slowly, under control."],
        easier: "Use your hands on the armrests to help you up.", formCheck: .squat)
    static let squat = Exercise("squat", "Bodyweight Squat", symbol: "figure.strengthtraining.functional",
        cues: ["Feet shoulder-width apart, toes slightly out.",
               "Sit your hips back and down, chest up.",
               "Push through your whole foot to stand."],
        easier: "Squat down to a chair and touch it lightly.", formCheck: .squat)
    static let wallPushUp = Exercise("wall-push-up", "Wall Push-Up", symbol: "figure.arms.open",
        cues: ["Hands on the wall at shoulder height.",
               "Keep your body in a straight line.",
               "Bend your elbows to bring your chest to the wall, then push away."],
        easier: "Stand closer to the wall.", formCheck: .pushUp)
    static let heelRaise = Exercise("heel-raise", "Supported Heel Raises", symbol: "figure.stand",
        cues: ["Hold the back of a chair or the counter.",
               "Rise up onto your toes.",
               "Lower slowly back down."],
        easier: "Do them sitting down, lifting your heels off the floor.")
    static let balance = Exercise("single-leg-balance", "Single-Leg Balance", symbol: "figure.cooldown",
        cues: ["Stand next to a counter with a hand ready.",
               "Lift one foot a little off the floor.",
               "Switch legs halfway through."],
        easier: "Keep one hand lightly on the counter the whole time.", formCheck: .balance)
    static let bandRow = Exercise("band-row", "Band or Towel Row", symbol: "figure.rower",
        cues: ["Hold a resistance band or a towel looped around a door handle.",
               "Pull your elbows back and squeeze your shoulder blades.",
               "Return slowly."],
        easier: "Use a lighter band, or do the movement with no resistance.")
    static let stepUp = Exercise("step-up", "Step-Ups", symbol: "figure.step.training",
        cues: ["Use the bottom stair, holding the rail.",
               "Step up with one foot and stand tall.",
               "Step down with control. Switch the leading leg halfway."],
        easier: "Use a lower step, or march on the spot.")
    static let marching = Exercise("seated-march", "Marching", symbol: "figure.walk",
        cues: ["March on the spot, lifting your knees.",
               "Swing your arms.",
               "Breathe steadily."],
        easier: "March while sitting in a chair.")
    static let gluteBridge = Exercise("glute-bridge", "Glute Bridge", symbol: "figure.core.training",
        cues: ["Lie on your back, knees bent, feet flat.",
               "Breathe out and lift your hips.",
               "Lower slowly."],
        easier: "Lift your hips only a small way.")
    static let birdDog = Exercise("bird-dog", "Bird Dog", symbol: "figure.pilates",
        cues: ["On hands and knees, back flat.",
               "Reach one arm forward and the opposite leg back.",
               "Return and switch sides."],
        easier: "Move only your arms, or only your legs.")
    static let farmerCarry = Exercise("farmer-carry", "Farmer's Carry", symbol: "figure.walk.motion",
        cues: ["Hold a weight, bag or water bottle in each hand.",
               "Stand tall with your shoulders back.",
               "Walk slowly and steadily."],
        easier: "Use lighter objects, or carry just one and switch hands.")

    // MARK: Postpartum
    static let breathing = Exercise("core-breathing", "Core Connection Breathing", symbol: "lungs",
        cues: ["Lie or sit comfortably with a hand on your belly.",
               "Breathe in and let your ribs and belly widen.",
               "Breathe out and gently draw your pelvic floor and lower belly in."],
        easier: "Just focus on slow, relaxed breaths.")
    static let pelvicFloor = Exercise("pelvic-floor", "Pelvic Floor Squeezes", symbol: "circle.circle",
        cues: ["Gently squeeze as if stopping the flow of urine.",
               "Hold for a few seconds, keep breathing.",
               "Fully relax between each squeeze."],
        easier: "Do short, quick squeezes with longer rests.")
    static let heelSlide = Exercise("heel-slide", "Heel Slides", symbol: "figure.flexibility",
        cues: ["Lie on your back, knees bent.",
               "Breathe out and slowly slide one heel away.",
               "Slide it back and switch legs."],
        easier: "Slide only part of the way.")
    static let clam = Exercise("clam", "Side-Lying Clam", symbol: "figure.mind.and.body",
        cues: ["Lie on your side, knees bent.",
               "Keep your feet together and lift your top knee.",
               "Lower slowly. Switch sides halfway."],
        easier: "Make the movement smaller.")

    // MARK: Hybrid fitness race stations (home-friendly versions)
    static let run = Exercise("run", "Run", symbol: "figure.run",
        cues: ["Run at a steady pace you could keep up for a long time.",
               "Relax your shoulders.",
               "Short, quick steps."],
        easier: "Brisk walk or jog on the spot.")
    static let skiPull = Exercise("ski-pull", "Ski Pull", symbol: "figure.skiing.crosscountry",
        cues: ["On a ski machine, or pull a band down from high up.",
               "Hinge at the hips as your arms drive down.",
               "Return tall and reach up."],
        easier: "Use a lighter band and a shorter range.")
    static let sledPush = Exercise("sled-push", "Sled Push / Wall Drive", symbol: "figure.cross.training",
        cues: ["Push a sled, or lean into a wall with straight arms.",
               "Drive with fast, powerful steps.",
               "Keep your back flat."],
        easier: "Slow, steady marching steps against the wall.")
    static let burpeeBroadJump = Exercise("burpee-broad-jump", "Burpee Broad Jump", symbol: "figure.jumprope",
        cues: ["Chest to the floor, then up.",
               "Jump forward with both feet.",
               "Land softly with bent knees."],
        easier: "Step back into a plank, step up, then step forward.")
    static let row = Exercise("row", "Row", symbol: "figure.rower",
        cues: ["On a rowing machine, or do band rows.",
               "Legs, then body, then arms.",
               "Return in reverse order."],
        easier: "Lower the resistance and slow the pace.")
    static let lunge = Exercise("walking-lunge", "Walking Lunges", symbol: "figure.strengthtraining.traditional",
        cues: ["Step forward and lower your back knee towards the floor.",
               "Keep your front knee over your foot.",
               "Hold a sandbag or backpack to add weight."],
        easier: "Do static lunges holding a chair.", formCheck: .lunge)
    static let wallBall = Exercise("wall-ball", "Wall Ball", symbol: "basketball",
        cues: ["Hold a medicine ball (or nothing) at your chest.",
               "Squat below parallel.",
               "Drive up and throw the ball to a target."],
        easier: "Squat to a box and press without throwing.", formCheck: .squat)

    static let all: [Exercise] = [
        sitToStand, squat, wallPushUp, heelRaise, balance, bandRow, stepUp, marching,
        gluteBridge, birdDog, farmerCarry, breathing, pelvicFloor, heelSlide, clam,
        run, skiPull, sledPush, burpeeBroadJump, row, lunge, wallBall
    ]

    static var withFormCheck: [Exercise] { all.filter { $0.formCheck != nil } }
}
