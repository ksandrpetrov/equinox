import XCTest
@testable import EquinoxKit

final class EventFetchRangeTests: XCTestCase {
    func testLongFetchIsSplitWithoutGapsOrOverlaps() throws {
        let first = CalendarDate(year: 2020, monthIndex: 0, day: 1)
        let last = CalendarDate(year: 2030, monthIndex: 11, day: 31)
        let chunks = EventFetchRange.chunks(first: first, last: last)
        XCTAssertEqual(chunks.first?.first, first)
        XCTAssertEqual(chunks.last?.last, last)
        XCTAssertTrue(chunks.allSatisfy { $0.last.compare($0.first) <= 365 })
        for (previous, next) in zip(chunks, chunks.dropFirst()) {
            XCTAssertEqual(previous.last.addingDays(1), next.first)
        }
    }

    func testFetchChunksRespectSupportedBoundariesAndRejectReversedRanges() {
        let first = CalendarDate.minimumSupported
        let last = CalendarDate.maximumSupported
        XCTAssertEqual(EventFetchRange.chunks(first: first, last: first).count, 1)
        XCTAssertEqual(EventFetchRange.chunks(first: last, last: last).last?.last, last)
        XCTAssertTrue(EventFetchRange.chunks(first: last, last: first).isEmpty)
        XCTAssertTrue(EventFetchRange.chunks(first: first.addingDays(-1), last: first).isEmpty)
    }

    func testFetchRangeExtendsForAgendaBounds() {
        let gridFirst = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let gridLast = CalendarDate(year: 2026, monthIndex: 5, day: 30)
        let agendaFirst = CalendarDate(year: 2026, monthIndex: 4, day: 20)
        let agendaLast = CalendarDate(year: 2026, monthIndex: 6, day: 10)

        let range = EventFetchRange.range(
            coveringGridFrom: gridFirst,
            through: gridLast,
            agendaFirst: agendaFirst,
            agendaLast: agendaLast
        )
        XCTAssertEqual(range.first, agendaFirst)
        XCTAssertEqual(range.last, agendaLast)
    }

    func testFetchRangeUsesGridWhenAgendaInsideGrid() {
        let gridFirst = CalendarDate(year: 2026, monthIndex: 5, day: 5)
        let gridLast = CalendarDate(year: 2026, monthIndex: 5, day: 30)
        let agendaFirst = CalendarDate(year: 2026, monthIndex: 5, day: 10)
        let agendaLast = CalendarDate(year: 2026, monthIndex: 5, day: 12)

        let range = EventFetchRange.range(
            coveringGridFrom: gridFirst,
            through: gridLast,
            agendaFirst: agendaFirst,
            agendaLast: agendaLast
        )
        XCTAssertEqual(range.first, gridFirst)
        XCTAssertEqual(range.last, gridLast)
    }

    func testFetchRangeNoAgendaBoundsReturnsGridOnly() {
        let gridFirst = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let gridLast = CalendarDate(year: 2026, monthIndex: 5, day: 30)

        let range = EventFetchRange.range(
            coveringGridFrom: gridFirst,
            through: gridLast,
            agendaFirst: nil,
            agendaLast: nil
        )
        XCTAssertEqual(range.first, gridFirst)
        XCTAssertEqual(range.last, gridLast)
    }

    func testNearbyPendingRangesAreCoalesced() {
        let current = (
            first: CalendarDate(year: 2026, monthIndex: 5, day: 1),
            last: CalendarDate(year: 2026, monthIndex: 5, day: 30)
        )
        let incoming = (
            first: CalendarDate(year: 2026, monthIndex: 4, day: 20),
            last: CalendarDate(year: 2026, monthIndex: 6, day: 10)
        )

        let result = EventFetchRange.coalesced(current: current, incoming: incoming)

        XCTAssertEqual(result.first, incoming.first)
        XCTAssertEqual(result.last, incoming.last)
    }

    func testFarPendingRangeSupersedesStaleRange() {
        let current = (
            first: CalendarDate(year: 2026, monthIndex: 5, day: 1),
            last: CalendarDate(year: 2026, monthIndex: 5, day: 30)
        )
        let incoming = (
            first: CalendarDate(year: 3333, monthIndex: 10, day: 1),
            last: CalendarDate.maximumSupported
        )

        let result = EventFetchRange.coalesced(current: current, incoming: incoming)

        XCTAssertEqual(result.first, incoming.first)
        XCTAssertEqual(result.last, incoming.last)
    }
}
