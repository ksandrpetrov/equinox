import Foundation

enum AgendaDisplayRange {
    static let initialPastDays = 14
    static let initialFutureDays = 45
    static let extensionChunkDays = 30
    static let extendThresholdDays = 10

    /// Initial agenda window: a little past, mostly future, anchored on the launch day (today).
    static func initialRange(anchor: CalendarDate) -> (first: CalendarDate, last: CalendarDate) {
        (
            first: anchor.addingDays(-initialPastDays),
            last: anchor.addingDays(initialFutureDays)
        )
    }

    static func shouldExtendPast(visible: CalendarDate, rangeFirst: CalendarDate) -> Bool {
        visible.addingDays(-extendThresholdDays) < rangeFirst
    }

    static func shouldExtendFuture(visible: CalendarDate, rangeLast: CalendarDate) -> Bool {
        visible.addingDays(extendThresholdDays) > rangeLast
    }

    static func extendedPast(from rangeFirst: CalendarDate) -> CalendarDate {
        rangeFirst.addingDays(-extensionChunkDays)
    }

    static func extendedFuture(from rangeLast: CalendarDate) -> CalendarDate {
        rangeLast.addingDays(extensionChunkDays)
    }

    /// Expands `first`/`last` until `date` is inside the range.
    static func rangeCovering(
        date: CalendarDate,
        first: CalendarDate,
        last: CalendarDate
    ) -> (first: CalendarDate, last: CalendarDate) {
        var expandedFirst = first
        var expandedLast = last
        while date < expandedFirst {
            expandedFirst = extendedPast(from: expandedFirst)
        }
        while date > expandedLast {
            expandedLast = extendedFuture(from: expandedLast)
        }
        return (expandedFirst, expandedLast)
    }
}
