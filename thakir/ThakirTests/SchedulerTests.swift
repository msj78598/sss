import XCTest
@testable import Thakir

final class SchedulerTests: XCTestCase {
    func testFirstGoodReviewSchedulesOneDay() {
        let card = Card(front: "أ", back: "ب")
        let now = Date()
        let next = Scheduler.schedule(card, grade: .good, now: now)
        XCTAssertEqual(next.interval, 1)
        XCTAssertEqual(next.repetitions, 1)
        XCTAssertEqual(next.reviewCount, 1)
        XCTAssertEqual(next.dueDate.timeIntervalSince(now), 86_400, accuracy: 1)
    }

    func testAgainResetsAndReschedulesInTenMinutes() {
        var card = Card(front: "أ", back: "ب")
        card.repetitions = 3
        card.interval = 15
        let now = Date()
        let next = Scheduler.schedule(card, grade: .again, now: now)
        XCTAssertEqual(next.interval, 0)
        XCTAssertEqual(next.repetitions, 0)
        XCTAssertEqual(next.lapses, 1)
        XCTAssertEqual(next.dueDate.timeIntervalSince(now), 600, accuracy: 1)
        XCTAssertLessThan(next.easeFactor, card.easeFactor)
    }

    func testIntervalsGrowWithRepetitions() {
        var card = Card(front: "أ", back: "ب")
        var intervals: [Int] = []
        for _ in 0..<4 {
            card = Scheduler.schedule(card, grade: .good)
            intervals.append(card.interval)
        }
        XCTAssertEqual(intervals[0], 1)
        XCTAssertEqual(intervals[1], 6)
        XCTAssertGreaterThan(intervals[2], intervals[1])
        XCTAssertGreaterThan(intervals[3], intervals[2])
    }

    func testEaseFactorNeverBelowFloor() {
        var card = Card(front: "أ", back: "ب")
        for _ in 0..<20 { card = Scheduler.schedule(card, grade: .again) }
        XCTAssertGreaterThanOrEqual(card.easeFactor, 1.3)
    }
}
