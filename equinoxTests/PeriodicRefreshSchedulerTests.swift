import XCTest
@testable import EquinoxKit

@MainActor
final class PeriodicRefreshSchedulerTests: XCTestCase {
    func testMinuteBoundariesAcrossClockTransitionsAndMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        for timestamp in [
            "2026-11-01T08:10:00Z", "2026-11-01T09:10:00Z",
            "2026-11-01T08:59:00Z", "2026-11-01T09:59:00Z",
            "2026-03-08T09:59:00Z", "2026-09-13T06:59:00Z",
        ] {
            let minute = try XCTUnwrap(ISO8601DateFormatter().date(from: timestamp))
            for seconds in [0.0, 15.25, 59.5] {
                var intervals: [TimeInterval] = []
                let scheduler = PeriodicRefreshScheduler(schedule: { interval, _ in
                    intervals.append(interval)
                    return Timer(timeInterval: interval, repeats: false) { _ in }
                }, now: { minute.addingTimeInterval(seconds) }, calendar: calendar, onTick: {})
                scheduler.start()
                scheduler.stop()
                XCTAssertEqual(try XCTUnwrap(intervals.first), max(1, 60 - seconds), accuracy: 0.001, timestamp)
            }
        }
    }

    func testSchedulerRecomputesBoundaryAfterEachTick() throws {
        var now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-12T23:59:45Z"))
        var intervals: [TimeInterval] = []
        var callbacks: [@MainActor () -> Void] = []
        let scheduler = PeriodicRefreshScheduler(schedule: { interval, callback in
            intervals.append(interval)
            callbacks.append(callback)
            return Timer(timeInterval: interval, repeats: false) { _ in }
        }, now: { now }, onTick: {})
        scheduler.start()
        now = now.addingTimeInterval(20)
        try XCTUnwrap(callbacks.first)()
        scheduler.stop()
        XCTAssertEqual(intervals, [15, 55])
    }

    func testStoppedSchedulerIgnoresAlreadyQueuedTick() throws {
        var callbacks: [@MainActor () -> Void] = []
        var timers: [Timer] = []
        var ticks = 0
        let scheduler = PeriodicRefreshScheduler(schedule: { _, callback in
            callbacks.append(callback)
            let timer = Timer(timeInterval: 60, repeats: false) { _ in }
            timers.append(timer)
            return timer
        }, onTick: { ticks += 1 })
        defer { scheduler.stop() }
        scheduler.start()
        scheduler.start()
        XCTAssertEqual(callbacks.count, 1)
        let oldTick = try XCTUnwrap(callbacks.first)
        let oldTimer = try XCTUnwrap(timers.first)
        XCTAssertTrue(oldTimer.isValid)
        scheduler.stop()
        XCTAssertFalse(oldTimer.isValid, "Stopping must release the native timer as well as ignore its callback")
        oldTick()
        XCTAssertEqual(ticks, 0)
        XCTAssertEqual(callbacks.count, 1)
        scheduler.start()
        let currentTimer = try XCTUnwrap(timers.last)
        XCTAssertTrue(currentTimer.isValid)
        oldTick()
        XCTAssertEqual(ticks, 0, "A tick from the previous run must not affect the restarted timer")
        try XCTUnwrap(callbacks.dropFirst().first)()
        XCTAssertEqual(ticks, 1)
        XCTAssertEqual(callbacks.count, 3)
        XCTAssertFalse(currentTimer.isValid, "Rescheduling invalidates the previous timer")
        let nextTimer = try XCTUnwrap(timers.last)
        XCTAssertTrue(nextTimer.isValid)
        XCTAssertFalse(nextTimer === currentTimer)
        scheduler.stop()
        XCTAssertFalse(nextTimer.isValid)
    }

    func testStoppingInsideTickDoesNotScheduleAnotherTimer() throws {
        var callbacks: [@MainActor () -> Void] = []
        var scheduler: PeriodicRefreshScheduler?
        scheduler = PeriodicRefreshScheduler(schedule: { _, callback in
            callbacks.append(callback)
            return Timer(timeInterval: 60, repeats: false) { _ in }
        }, onTick: { scheduler?.stop() })
        scheduler?.start()
        try XCTUnwrap(callbacks.first)()
        XCTAssertEqual(callbacks.count, 1)
        scheduler = nil
    }
}
