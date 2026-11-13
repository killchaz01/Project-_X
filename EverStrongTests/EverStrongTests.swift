import XCTest
import CoreGraphics
@testable import EverStrong

final class PoseMathTests: XCTestCase {
    func testRightAngle() {
        let a = PoseMath.angle(CGPoint(x: 0, y: 1), CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0))
        XCTAssertEqual(a, 90, accuracy: 0.001)
    }

    func testStraightLegIs180() {
        let a = PoseMath.angle(CGPoint(x: 0.5, y: 0.2), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.8))
        XCTAssertEqual(a, 180, accuracy: 0.001)
    }

    func testLean() {
        XCTAssertEqual(PoseMath.leanFromVertical(hip: .zero, shoulder: CGPoint(x: 0, y: -1)), 0, accuracy: 0.001)
        XCTAssertEqual(PoseMath.leanFromVertical(hip: .zero, shoulder: CGPoint(x: 1, y: -1)), 45, accuracy: 0.001)
    }
}

final class SquatAnalyzerTests: XCTestCase {
    private func run(_ angles: [Double], lean: Double? = nil, on analyzer: inout SquatAnalyzer) -> [SquatAnalyzer.Feedback] {
        angles.compactMap { analyzer.update(kneeAngle: $0, torsoLean: lean) }
    }

    func testCountsDeepRep() {
        var a = SquatAnalyzer()
        let fb = run([175, 150, 120, 95, 120, 150, 170], on: &a)
        XCTAssertEqual(a.reps, 1)
        XCTAssertEqual(fb.count, 1)
        XCTAssertTrue(fb[0].isPositive)
        XCTAssertTrue(fb[0].message.contains("Great depth"))
    }

    func testShallowRepNotCounted() {
        var a = SquatAnalyzer()
        let fb = run([175, 138, 135, 160], on: &a)
        XCTAssertEqual(a.reps, 0)
        XCTAssertEqual(fb.first?.isPositive, false)
    }

    func testLeanWarning() {
        var a = SquatAnalyzer()
        let fb = run([175, 120, 100, 170], lean: 60, on: &a)
        XCTAssertEqual(a.reps, 1)
        XCTAssertTrue(fb[0].message.contains("chest"))
    }

    func testMultipleReps() {
        var a = SquatAnalyzer()
        _ = run([175, 110, 170, 112, 170, 100, 175], on: &a)
        XCTAssertEqual(a.reps, 3)
    }
}

final class WorkoutSessionTests: XCTestCase {
    func testPhasesSkipFinalRest() {
        let w = WorkoutLibrary.micro[0]
        let s = WorkoutSession(workout: w, getReadySeconds: 5)
        XCTAssertEqual(s.phases.first?.kind, .getReady)
        XCTAssertEqual(s.phases.last?.kind, .work)
        XCTAssertEqual(s.phases.filter { $0.kind == .work }.count, w.steps.count * w.rounds)
    }

    func testRunsToCompletion() {
        let w = WorkoutLibrary.micro[1]
        var s = WorkoutSession(workout: w, getReadySeconds: 3)
        var finished = false
        for _ in 0..<10_000 {
            if s.tick() == .finished { finished = true; break }
        }
        XCTAssertTrue(finished)
        XCTAssertTrue(s.isFinished)
        XCTAssertEqual(s.elapsed, 3 + s.phases.dropFirst().reduce(0) { $0 + $1.seconds })
    }

    func testPauseStopsClock() {
        var s = WorkoutSession(workout: WorkoutLibrary.micro[0])
        s.isPaused = true
        let before = s.remaining
        XCTAssertNil(s.tick())
        XCTAssertEqual(s.remaining, before)
    }
}

final class ContentTests: XCTestCase {
    func testEveryFocusHasPrograms() {
        for focus in FitnessFocus.allCases {
            XCTAssertFalse(WorkoutLibrary.programs(for: focus).isEmpty, "\(focus) has no programs")
        }
    }

    func testIDsUnique() {
        XCTAssertEqual(Set(WorkoutLibrary.all.map(\.id)).count, WorkoutLibrary.all.count)
        XCTAssertEqual(Set(ExerciseLibrary.all.map(\.id)).count, ExerciseLibrary.all.count)
    }

    func testMicroWorkoutsAreShort() {
        for w in WorkoutLibrary.micro { XCTAssertLessThanOrEqual(w.totalSeconds, 6 * 60, w.title) }
    }

    func testPhoneSanitising() {
        XCTAssertEqual(PhoneNumber.dialable("+1 (555) 010-2030"), "+15550102030")
        XCTAssertEqual(PhoneNumber.dialable("07700 900+123"), "07700900123")
    }
}
