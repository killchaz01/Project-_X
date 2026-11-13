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
}

final class RepAnalyzerPresetTests: XCTestCase {
    func testPushUpCountsElbowBend() {
        var a = RepAnalyzer.pushUp
        let fb = [170, 130, 90, 130, 165].compactMap { a.update(kneeAngle: $0, torsoLean: 5) }
        XCTAssertEqual(a.reps, 1)
        XCTAssertTrue(fb[0].message.contains("Full range"))
    }

    func testPushUpSagWarning() {
        var a = RepAnalyzer.pushUp
        let fb = [170, 100, 165].compactMap { a.update(kneeAngle: $0, torsoLean: 40) }
        XCTAssertTrue(fb[0].message.contains("straight line"))
    }

    func testLungeShallowMessage() {
        var a = RepAnalyzer.lunge
        let fb = [175, 135, 170].compactMap { a.update(kneeAngle: $0) }
        XCTAssertEqual(a.reps, 0)
        XCTAssertTrue(fb[0].message.contains("back knee"))
    }
}

final class BalanceAnalyzerTests: XCTestCase {
    func testFootLiftDetection() {
        let l = CGPoint(x: 0.4, y: 0.80), r = CGPoint(x: 0.6, y: 0.90)
        XCTAssertTrue(BalanceAnalyzer.isFootLifted(leftAnkle: l, rightAnkle: r, legLength: 0.4))
        XCTAssertFalse(BalanceAnalyzer.isFootLifted(leftAnkle: l, rightAnkle: CGPoint(x: 0.6, y: 0.81), legLength: 0.4))
        XCTAssertFalse(BalanceAnalyzer.isFootLifted(leftAnkle: l, rightAnkle: r, legLength: 0))
    }

    func testHoldTimingAndMilestone() {
        var b = BalanceAnalyzer()
        var messages: [String] = []
        // Foot up from t=0 to t=12 (sampled 10x per second), then down.
        for i in 0...120 {
            if let fb = b.update(lifted: true, time: Double(i) / 10) { messages.append(fb.message) }
        }
        XCTAssertEqual(b.currentHold, 12)
        XCTAssertEqual(messages, ["10 seconds. Keep going!"])
        for i in 121...140 {
            if let fb = b.update(lifted: false, time: Double(i) / 10) { messages.append(fb.message) }
        }
        XCTAssertEqual(b.best, 12)
        XCTAssertEqual(b.currentHold, 0)
        XCTAssertEqual(messages.last, "You held for 12 seconds. Switch legs and try again.")
    }

    func testBriefDropoutDoesNotEndHold() {
        var b = BalanceAnalyzer()
        _ = b.update(lifted: true, time: 0)
        _ = b.update(lifted: true, time: 3)
        XCTAssertNil(b.update(lifted: false, time: 3.3))   // within grace period
        _ = b.update(lifted: true, time: 5)
        XCTAssertEqual(b.currentHold, 5)
    }
}

final class ProgressStatsTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2   // Monday
        return c
    }()

    private func day(_ d: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: hour))!
    }

    func testStreakCountsBackFromToday() {
        XCTAssertEqual(ProgressStats.streak(activeDates: [day(11), day(12), day(13)], today: day(13), calendar: cal), 3)
    }

    func testStreakSurvivesUntilEndOfToday() {
        XCTAssertEqual(ProgressStats.streak(activeDates: [day(11), day(12)], today: day(13), calendar: cal), 2)
    }

    func testStreakBrokenByGap() {
        XCTAssertEqual(ProgressStats.streak(activeDates: [day(9), day(10)], today: day(13), calendar: cal), 0)
        XCTAssertEqual(ProgressStats.streak(activeDates: [day(9), day(10), day(13)], today: day(13), calendar: cal), 1)
    }

    func testWeekDaysStartOnMonday() {
        // 13 Nov 2026 is a Friday; that week runs Mon 9 – Sun 15.
        let week = ProgressStats.weekDays(containing: day(13), calendar: cal)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(cal.component(.day, from: week[0]), 9)
        XCTAssertEqual(cal.component(.day, from: week[6]), 15)
    }

    func testActiveDaysThisWeekIgnoresOtherWeeks() {
        let active = ProgressStats.activeDaysThisWeek(activeDates: [day(6), day(9), day(9, hour: 18), day(12)],
                                                      today: day(13), calendar: cal)
        XCTAssertEqual(active.count, 2)
    }

}
