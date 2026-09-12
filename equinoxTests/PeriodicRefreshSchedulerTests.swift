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
        callbacks[0]()
        scheduler.stop()
        XCTAssertEqual(intervals, [15, 55])
    }

    func testStoppedSchedulerIgnoresAlreadyQueuedTick() {
        var callbacks: [@MainActor () -> Void] = []
        var ticks = 0
        let scheduler = PeriodicRefreshScheduler(schedule: { _, callback in
            callbacks.append(callback)
            return Timer(timeInterval: 60, repeats: false) { _ in }
        }, onTick: { ticks += 1 })
        scheduler.start()
        scheduler.start()
        XCTAssertEqual(callbacks.count, 1)
        scheduler.stop()
        callbacks[0]()
        XCTAssertEqual(ticks, 0)
        XCTAssertEqual(callbacks.count, 1)
        scheduler.start()
        callbacks[0]()
        XCTAssertEqual(ticks, 0, "A tick from the previous run must not affect the restarted timer")
        callbacks[1]()
        XCTAssertEqual(ticks, 1)
        XCTAssertEqual(callbacks.count, 3)
        scheduler.stop()
    }

    func testStoppingInsideTickDoesNotScheduleAnotherTimer() {
        var callbacks: [@MainActor () -> Void] = []
        var scheduler: PeriodicRefreshScheduler?
        scheduler = PeriodicRefreshScheduler(schedule: { _, callback in
            callbacks.append(callback)
            return Timer(timeInterval: 60, repeats: false) { _ in }
        }, onTick: { scheduler?.stop() })
        scheduler?.start()
        callbacks[0]()
        XCTAssertEqual(callbacks.count, 1)
        scheduler = nil
    }
}
