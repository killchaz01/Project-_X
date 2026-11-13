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

/// Counts squat reps from a stream of knee angles and gives simple, kind feedback.
struct SquatAnalyzer {
    enum Phase { case standing, descending }

    struct Feedback: Equatable {
        let message: String
        let isPositive: Bool
    }

    /// Knee angle above which we consider the person standing.
    var standingAngle: Double = 155
    /// Knee angle that must be reached for a movement to count as a rep.
    var repThreshold: Double = 125
    /// Below this the squat is "good depth" (around thighs parallel).
    var goodDepthAngle: Double = 100
    /// Torso lean beyond this triggers a "chest up" cue.
    var maxLean: Double = 50

    private(set) var phase: Phase = .standing
    private(set) var reps = 0
    private(set) var deepestAngle: Double = 180
    private var maxLeanThisRep: Double = 0

    mutating func reset() {
        phase = .standing
        reps = 0
        deepestAngle = 180
        maxLeanThisRep = 0
    }

    /// Feed one frame. Returns feedback when a rep finishes.
    mutating func update(kneeAngle: Double, torsoLean: Double? = nil) -> Feedback? {
        switch phase {
        case .standing:
            if kneeAngle < standingAngle - 15 {
                phase = .descending
                deepestAngle = kneeAngle
                maxLeanThisRep = torsoLean ?? 0
            }
            return nil
        case .descending:
            deepestAngle = min(deepestAngle, kneeAngle)
            if let torsoLean { maxLeanThisRep = max(maxLeanThisRep, torsoLean) }
            guard kneeAngle >= standingAngle else { return nil }
            phase = .standing
            guard deepestAngle <= repThreshold else {
                return Feedback(message: "Try going a little lower, only as far as feels comfortable.", isPositive: false)
            }
            reps += 1
            if maxLeanThisRep > maxLean {
                return Feedback(message: "Rep \(reps). Keep your chest a bit more upright.", isPositive: false)
            }
            if deepestAngle <= goodDepthAngle {
                return Feedback(message: "Rep \(reps). Great depth!", isPositive: true)
            }
            return Feedback(message: "Rep \(reps). Nice and controlled.", isPositive: true)
        }
    }
}
