import XCTest
@testable import EquinoxKit

@MainActor
final class CalendarTestContext {
    let suite = "equinox.app-state.tests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let store = StubCalendarEventStore()
    let appState: AppState

    init() throws {
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let calendar = Calendar.equinoxGregorian(timeZone: TimeZone(secondsFromGMT: 0)!)
        appState = AppState(
            calendar: calendar, calendarStore: store,
            preferences: PreferencesStore(defaults: defaults, notificationCenter: NotificationCenter()),
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
        participationStatus: EventParticipationStatus? = nil
    ) -> DayEvent {
        let end = isAllDay ? appState.calendar.date(byAdding: .day, value: 1, to: start)! : start.addingTimeInterval(3600)
        return DayEvent(
            id: "event-\(start.timeIntervalSinceReferenceDate)", eventIdentifier: "event",
            calendarItemIdentifier: "series", title: title, location: location, notes: nil, url: nil,
            startDate: start, endDate: end,
            slotStartDate: start, slotEndDate: end,
            isEventAllDay: isAllDay, isSlotAllDay: isAllDay, joinURL: isAllDay ? nil : URL(string: "https://zoom.us/j/123"),
            calendarIdentifier: "work", calendarTitle: "Work",
            calendarColorRed: 0.2, calendarColorGreen: 0.5, calendarColorBlue: 0.8, calendarColorAlpha: 1,
            isRecurring: true, allowsContentModifications: true, participationStatus: participationStatus
        )
    }
}
