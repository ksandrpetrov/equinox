import XCTest
@testable import equinox

final class CalendarListingTests: XCTestCase {
    func testSortCalendarsGroupsBySource() {
        let items = [
            CalendarListItem(id: "b", title: "Beta", sourceTitle: "Google", sourceIdentifier: "g", colorHex: "#fff", allowsContentModifications: true, isSubscribed: false, type: "caldav"),
            CalendarListItem(id: "a", title: "Alpha", sourceTitle: "Google", sourceIdentifier: "g", colorHex: "#fff", allowsContentModifications: true, isSubscribed: false, type: "caldav"),
            CalendarListItem(id: "w", title: "Work", sourceTitle: "iCloud", sourceIdentifier: "i", colorHex: "#000", allowsContentModifications: true, isSubscribed: false, type: "caldav"),
        ]

        let sorted = CalendarListing.sortCalendarsForDisplay(items)
        XCTAssertEqual(sorted.map(\.id), ["a", "b", "w"])
    }

    func testFilterDisplayableCalendarsRemovesMissingColor() {
        let items = [
            CalendarListItem(id: "a", title: "A", sourceTitle: "S", sourceIdentifier: "s", colorHex: "#fff", allowsContentModifications: true, isSubscribed: false, type: "local"),
            CalendarListItem(id: "b", title: "B", sourceTitle: "S", sourceIdentifier: "s", colorHex: nil, allowsContentModifications: true, isSubscribed: false, type: "local"),
        ]

        let filtered = CalendarListing.filterDisplayableCalendars(items)
        XCTAssertEqual(filtered.map(\.id), ["a"])
    }
}
