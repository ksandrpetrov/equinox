import XCTest
@testable import EquinoxKit

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

    func testFilterEntriesPreservesSourceHeaders() {
        let entries: [CalendarListEntry] = [
            .source("Google"),
            .calendar(SelectableCalendar(id: "work", title: "Work Calendar", sourceTitle: "Google", isSelected: true, colorRed: 1, colorGreen: 0, colorBlue: 0, colorAlpha: 1, allowsContentModifications: true)),
            .calendar(SelectableCalendar(id: "personal", title: "Personal", sourceTitle: "Google", isSelected: true, colorRed: 0, colorGreen: 1, colorBlue: 0, colorAlpha: 1, allowsContentModifications: true)),
        ]
        let filtered = CalendarListEntryFiltering.filter(entries, query: "work")
        XCTAssertEqual(filtered.count, 2)
        if case .source(let name) = filtered[0] {
            XCTAssertEqual(name, "Google")
        } else {
            XCTFail("Expected source header")
        }
    }

    func testFilterEntriesEmptyQueryReturnsAll() {
        let entries = sampleGroupedEntries()
        XCTAssertEqual(CalendarListEntryFiltering.filter(entries, query: ""), entries)
        XCTAssertEqual(CalendarListEntryFiltering.filter(entries, query: "   "), entries)
    }

    func testFilterEntriesNoMatchReturnsEmptyList() {
        let entries = sampleGroupedEntries()
        XCTAssertEqual(CalendarListEntryFiltering.filter(entries, query: "nonexistent"), [])
    }

    func testFilterEntriesIsCaseInsensitive() {
        let entries: [CalendarListEntry] = [
            .source("Google"),
            .calendar(SelectableCalendar(id: "work", title: "Work Calendar", sourceTitle: "Google", isSelected: true, colorRed: 1, colorGreen: 0, colorBlue: 0, colorAlpha: 1, allowsContentModifications: true)),
        ]
        let filtered = CalendarListEntryFiltering.filter(entries, query: "WORK")
        XCTAssertEqual(filtered.count, 2)
    }

    func testFilterEntriesAcrossMultipleSources() {
        let entries: [CalendarListEntry] = [
            .source("Google"),
            .calendar(SelectableCalendar(id: "g-work", title: "Work", sourceTitle: "Google", isSelected: true, colorRed: 1, colorGreen: 0, colorBlue: 0, colorAlpha: 1, allowsContentModifications: true)),
            .source("iCloud"),
            .calendar(SelectableCalendar(id: "i-work", title: "Work", sourceTitle: "iCloud", isSelected: true, colorRed: 0, colorGreen: 0, colorBlue: 1, colorAlpha: 1, allowsContentModifications: true)),
        ]
        let filtered = CalendarListEntryFiltering.filter(entries, query: "work")
        XCTAssertEqual(filtered.count, 4)
        if case .source(let first) = filtered[0] { XCTAssertEqual(first, "Google") } else { XCTFail() }
        if case .source(let second) = filtered[2] { XCTAssertEqual(second, "iCloud") } else { XCTFail() }
    }

    func testSortCalendarsOrdersSourcesAlphabetically() {
        let items = [
            CalendarListItem(id: "i", title: "Personal", sourceTitle: "iCloud", sourceIdentifier: "i", colorHex: "#fff", allowsContentModifications: true, isSubscribed: false, type: "caldav"),
            CalendarListItem(id: "g", title: "Work", sourceTitle: "Google", sourceIdentifier: "g", colorHex: "#fff", allowsContentModifications: true, isSubscribed: false, type: "caldav"),
        ]
        let sorted = CalendarListing.sortCalendarsForDisplay(items)
        XCTAssertEqual(sorted.map(\.sourceTitle), ["Google", "iCloud"])
    }

    func testSortCalendarsIsStableForDuplicateSourceAndCalendarTitles() {
        let items = [
            CalendarListItem(id: "z", title: "Work", sourceTitle: "Google", sourceIdentifier: "account-b", colorHex: "#fff", allowsContentModifications: true, isSubscribed: false, type: "caldav"),
            CalendarListItem(id: "b", title: "Work", sourceTitle: "Google", sourceIdentifier: "account-a", colorHex: "#fff", allowsContentModifications: true, isSubscribed: false, type: "caldav"),
            CalendarListItem(id: "a", title: "Work", sourceTitle: "Google", sourceIdentifier: "account-a", colorHex: "#fff", allowsContentModifications: true, isSubscribed: false, type: "caldav"),
        ]

        XCTAssertEqual(CalendarListing.sortCalendarsForDisplay(items).map(\.id), ["a", "b", "z"])
    }

    func testFilterEntriesOmitsSourceWithNoMatchingCalendars() {
        let entries: [CalendarListEntry] = [
            .source("Google"),
            .calendar(SelectableCalendar(id: "personal", title: "Personal", sourceTitle: "Google", isSelected: true, colorRed: 1, colorGreen: 0, colorBlue: 0, colorAlpha: 1, allowsContentModifications: true)),
            .source("iCloud"),
            .calendar(SelectableCalendar(id: "home", title: "Home", sourceTitle: "iCloud", isSelected: true, colorRed: 0, colorGreen: 0, colorBlue: 1, colorAlpha: 1, allowsContentModifications: true)),
        ]
        let filtered = CalendarListEntryFiltering.filter(entries, query: "work")
        XCTAssertEqual(filtered, [])
    }

    func testFilterEntriesMatchesSourceTitle() {
        let entries = sampleGroupedEntries()
        let filtered = CalendarListEntryFiltering.filter(entries, query: "icloud")

        XCTAssertEqual(filtered.count, 2)
        if case .source(let source) = filtered[0] {
            XCTAssertEqual(source, "iCloud")
        } else {
            XCTFail("Expected source header")
        }
    }

    func testFilterEntriesDoesNotDropCalendarWithoutSourceHeader() {
        let calendar = SelectableCalendar(
            id: "local",
            title: "Local",
            sourceTitle: "",
            isSelected: true,
            colorRed: 1,
            colorGreen: 0,
            colorBlue: 0,
            colorAlpha: 1,
            allowsContentModifications: true
        )

        XCTAssertEqual(CalendarListEntryFiltering.filter([.calendar(calendar)], query: "local"), [.calendar(calendar)])
    }

    private func sampleGroupedEntries() -> [CalendarListEntry] {
        [
            .source("Google"),
            .calendar(SelectableCalendar(id: "work", title: "Work Calendar", sourceTitle: "Google", isSelected: true, colorRed: 1, colorGreen: 0, colorBlue: 0, colorAlpha: 1, allowsContentModifications: true)),
            .source("iCloud"),
            .calendar(SelectableCalendar(id: "home", title: "Home", sourceTitle: "iCloud", isSelected: true, colorRed: 0, colorGreen: 0, colorBlue: 1, colorAlpha: 1, allowsContentModifications: true)),
        ]
    }
}
