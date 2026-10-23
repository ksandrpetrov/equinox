import XCTest
@testable import EquinoxKit

@MainActor
final class CalendarTestContext {
    let suite = "equinox.app-state.tests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let store = StubCalendarEventStore()
    let appState: AppState
    let now: Date

    init(now: Date = Date(timeIntervalSince1970: 1_789_214_400)) throws {
        self.now = now // Default: 2026-09-12 12:00 UTC
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let calendar = Calendar.equinoxGregorian(timeZone: TimeZone(secondsFromGMT: 0)!)
        appState = AppState(
            calendar: calendar, calendarStore: store,
            preferences: PreferencesStore(defaults: defaults, notificationCenter: NotificationCenter()),
            now: { now },
            resetShortcuts: {}, disableLaunchAtLogin: {}
        )
    }

    func finishInitialization() async {
        await appState.waitForInitialization()
        XCTAssertEqual(appState.events.calendarAccessStatus, .authorized)
        XCTAssertNotNil(store.externalChangeHandler)
    }

    func cleanUp() { defaults.removePersistentDomain(forName: suite) }

    func event(
        start: Date,
        title: String = "Test meeting",
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        participationStatus: EventParticipationStatus? = nil
    ) -> DayEvent {
        let end = isAllDay ? appState.calendar.date(byAdding: .day, value: 1, to: start)! : start.addingTimeInterval(3600)
        return DayEvent(
            id: "event-\(start.timeIntervalSinceReferenceDate)", eventIdentifier: "event",
            calendarItemIdentifier: "series", title: title, location: location, notes: notes, url: nil,
            startDate: start, endDate: end,
            slotStartDate: start, slotEndDate: end,
            isEventAllDay: isAllDay, isSlotAllDay: isAllDay, joinURL: isAllDay ? nil : URL(string: "https://zoom.us/j/123"),
            calendarIdentifier: "work", calendarTitle: "Work",
            calendarColorRed: 0.2, calendarColorGreen: 0.5, calendarColorBlue: 0.8, calendarColorAlpha: 1,
            isRecurring: true, allowsContentModifications: true, participationStatus: participationStatus
        )
    }
}

/// Suspends navigation until the test releases it, including cancelled callers.
/// Returning normally after cancellation exercises the caller's cancellation guard.
@MainActor
final class ManualNavigationDelay {
    let suspended: XCTestExpectation
    let completed: XCTestExpectation
    private var continuations: [CheckedContinuation<Void, Never>] = []

    init(requests: Int = 1) {
        suspended = XCTestExpectation(description: "Navigation delays suspended")
        completed = XCTestExpectation(description: "Navigation delays resumed")
        suspended.expectedFulfillmentCount = requests
        completed.expectedFulfillmentCount = requests
    }

    func wait() async throws {
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
            suspended.fulfill()
        }
        completed.fulfill()
    }

    func resumeAll() {
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume() }
    }
}
