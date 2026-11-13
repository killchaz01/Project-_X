import CoreGraphics
import Foundation

/// Pure geometry used by the form check. No camera or Vision code here, so it is unit-testable.
enum PoseMath {
    /// Angle ABC in degrees (0–180), where B is the joint (e.g. hip–knee–ankle).
    static func angle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
        let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag = hypot(v1.dx, v1.dy) * hypot(v2.dx, v2.dy)
        guard mag > 0 else { return 180 }
        let cosine = max(-1, min(1, dot / mag))
        return acos(Double(cosine)) * 180 / .pi
    }

    /// How far the torso (hip → shoulder) leans away from vertical, in degrees.
    static func leanFromVertical(hip: CGPoint, shoulder: CGPoint) -> Double {
        let dx = Double(shoulder.x - hip.x)
        let dy = Double(shoulder.y - hip.y)
        guard dx != 0 || dy != 0 else { return 0 }
        return atan2(abs(dx), abs(dy)) * 180 / .pi
    }
}

/// Counts reps from a stream of joint angles and gives simple, kind feedback.
/// Works for any bend-and-straighten movement: squats and lunges (knee angle), push-ups (elbow angle).
struct RepAnalyzer {
    enum Phase { case extended, moving }

    struct Feedback: Equatable {
        let message: String
        let isPositive: Bool
    }

    /// Joint angle above which we consider the limb straight (standing tall / arms extended).
    var standingAngle: Double = 155
    /// Joint angle that must be reached for a movement to count as a rep.
    var repThreshold: Double = 125
    /// Below this the rep has "good depth" (for squats, around thighs parallel).
    var goodDepthAngle: Double = 100
    /// Posture measure (e.g. torso lean) beyond which a posture cue is given.
    var maxLean: Double = 50

    var shallowMessage = "Try going a little lower, only as far as feels comfortable."
    var leanMessage = "Keep your chest a bit more upright."
    var goodMessage = "Great depth!"
    var okMessage = "Nice and controlled."

    private(set) var phase: Phase = .extended
    private(set) var reps = 0
    private(set) var deepestAngle: Double = 180
    private var maxLeanThisRep: Double = 0

    static var squat: RepAnalyzer { RepAnalyzer() }

    static var lunge: RepAnalyzer {
        var a = RepAnalyzer()
        a.goodDepthAngle = 105
        a.maxLean = 35
        a.shallowMessage = "Lower your back knee a little more, if it feels comfortable."
        a.leanMessage = "Stay tall through your body."
        return a
    }

    static var pushUp: RepAnalyzer {
        var a = RepAnalyzer()
        a.standingAngle = 150
        a.repThreshold = 120
        a.goodDepthAngle = 95
        a.maxLean = 25
        a.shallowMessage = "Bend your elbows a little more."
        a.leanMessage = "Keep your body in one straight line."
        a.goodMessage = "Full range!"
        return a
    }

    mutating func reset() {
        phase = .extended
        reps = 0
        deepestAngle = 180
        maxLeanThisRep = 0
    }

    /// Feed one frame. `kneeAngle` is the working joint's angle; `torsoLean` the posture measure.
    /// Returns feedback when a rep finishes.
    mutating func update(kneeAngle: Double, torsoLean: Double? = nil) -> Feedback? {
        switch phase {
        case .extended:
            if kneeAngle < standingAngle - 15 {
                phase = .moving
                deepestAngle = kneeAngle
                maxLeanThisRep = torsoLean ?? 0
            }
            return nil
        case .moving:
            deepestAngle = min(deepestAngle, kneeAngle)
            if let torsoLean { maxLeanThisRep = max(maxLeanThisRep, torsoLean) }
            guard kneeAngle >= standingAngle else { return nil }
            phase = .extended
            guard deepestAngle <= repThreshold else {
                return Feedback(message: shallowMessage, isPositive: false)
            }
            reps += 1
            if maxLeanThisRep > maxLean {
                return Feedback(message: "Rep \(reps). \(leanMessage)", isPositive: false)
            }
            if deepestAngle <= goodDepthAngle {
                return Feedback(message: "Rep \(reps). \(goodMessage)", isPositive: true)
            }
            return Feedback(message: "Rep \(reps). \(okMessage)", isPositive: true)
        }
    }
}

typealias SquatAnalyzer = RepAnalyzer

/// Times how long one foot stays off the floor during a single-leg balance.
struct BalanceAnalyzer {
    /// One ankle must be higher than the other by this fraction of leg length to count as lifted.
    var liftThreshold: Double = 0.08
    /// Brief tracking drop-outs shorter than this don't end the hold.
    var graceSeconds: TimeInterval = 0.6

    private(set) var currentHold = 0
    private(set) var best = 0
    private var holdStart: TimeInterval?
    private var lastLifted: TimeInterval = 0
    private var lastMilestone = 0

    static func isFootLifted(leftAnkle: CGPoint, rightAnkle: CGPoint, legLength: Double, threshold: Double = 0.08) -> Bool {
        guard legLength > 0 else { return false }
        return abs(Double(leftAnkle.y - rightAnkle.y)) / legLength > threshold
    }

    mutating func reset() { self = BalanceAnalyzer(liftThreshold: liftThreshold, graceSeconds: graceSeconds) }

    init(liftThreshold: Double = 0.08, graceSeconds: TimeInterval = 0.6) {
        self.liftThreshold = liftThreshold
        self.graceSeconds = graceSeconds
    }

    /// Feed one frame with the current time in seconds.
    mutating func update(lifted: Bool, time: TimeInterval) -> RepAnalyzer.Feedback? {
        if lifted {
            lastLifted = time
            if holdStart == nil {
                holdStart = time
                lastMilestone = 0
            }
        }
        guard let start = holdStart else { return nil }

        if lifted || time - lastLifted < graceSeconds {
            currentHold = Int(time - start)
            best = max(best, currentHold)
            let milestone = currentHold / 10
            if milestone > lastMilestone {
                lastMilestone = milestone
                return RepAnalyzer.Feedback(message: "\(milestone * 10) seconds. Keep going!", isPositive: true)
            }
            return nil
        }

        // Foot is back down.
        let held = Int(lastLifted - start)
        holdStart = nil
        currentHold = 0
        guard held >= 2 else { return nil }
        return RepAnalyzer.Feedback(message: "You held for \(held) seconds. Switch legs and try again.", isPositive: true)
    }
}
