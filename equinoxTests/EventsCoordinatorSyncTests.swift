import XCTest
@testable import equinox

final class EventsCoordinatorSyncTests: XCTestCase {
    func testCreateAndDeleteEventCallSyncFromCalendarStore() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repoRoot.appendingPathComponent("equinox/App/EventsCoordinator.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(
            source.contains("try await calendarStore.createEvent(from: draft)\n            await syncFromCalendarStore()"),
            "createEvent should sync from calendar store after success"
        )
        XCTAssertTrue(
            source.contains("try await calendarStore.deleteEvent(identifier: identifier)\n            await syncFromCalendarStore()"),
            "deleteEvent should sync from calendar store after success"
        )
    }
}
