import Foundation

enum AgendaDisplayRange {
    static let initialPastDays = 14
    static let initialFutureDays = 45
    static let extensionChunkDays = 30
    static let extendThresholdDays = 10
    static let maximumNavigationSpanDays = initialPastDays + initialFutureDays + extensionChunkDays * 2

    /// Initial agenda window: a little past, mostly future, anchored on the launch day (today).
    static func initialRange(anchor: CalendarDate) -> (first: CalendarDate, last: CalendarDate) {
        (
            first: max(anchor.addingDays(-initialPastDays), CalendarDate.minimumSupported),
            last: min(anchor.addingDays(initialFutureDays), CalendarDate.maximumSupported)
        )
    }

    static func shouldExtendPast(visible: CalendarDate, rangeFirst: CalendarDate) -> Bool {
        visible.addingDays(-extendThresholdDays) < rangeFirst
    }

    static func shouldExtendFuture(visible: CalendarDate, rangeLast: CalendarDate) -> Bool {
        visible.addingDays(extendThresholdDays) > rangeLast
    }

    static func extendedPast(from rangeFirst: CalendarDate) -> CalendarDate {
        max(rangeFirst.addingDays(-extensionChunkDays), CalendarDate.minimumSupported)
    }

    static func extendedFuture(from rangeLast: CalendarDate) -> CalendarDate {
        min(rangeLast.addingDays(extensionChunkDays), CalendarDate.maximumSupported)
    }

    /// Expands `first`/`last` until `date` is inside the range.
    static func rangeCovering(
        date: CalendarDate,
        first: CalendarDate,
        last: CalendarDate
    ) -> (first: CalendarDate, last: CalendarDate) {
        guard date.isValid else { return (first, last) }
        guard date < first || date > last else { return (first, last) }

        // A deep link can jump centuries. Re-anchor instead of asking EventKit to fetch
        // every day between the old and new selection.
        let maximumIncrementalDistance = extensionChunkDays * 2
        if date < first, first.compare(date) > maximumIncrementalDistance {
            return initialRange(anchor: date)
        }
        if date > last, date.compare(last) > maximumIncrementalDistance {
            return initialRange(anchor: date)
        }

        let expandedFirst: CalendarDate
        if date < first {
            let chunks = (first.compare(date) + extensionChunkDays - 1) / extensionChunkDays
            expandedFirst = max(
                first.addingDays(-chunks * extensionChunkDays),
                CalendarDate.minimumSupported
            )
        } else {
            expandedFirst = first
        }

        let expandedLast: CalendarDate
        if date > last {
            let chunks = (date.compare(last) + extensionChunkDays - 1) / extensionChunkDays
            expandedLast = min(
                last.addingDays(chunks * extensionChunkDays),
                CalendarDate.maximumSupported
            )
        } else {
            expandedLast = last
        }
        // Month-button navigation should not retain every previously visited month.
        // Scrolling still extends the current window while its visible date stays inside it.
        if expandedLast.compare(expandedFirst) > maximumNavigationSpanDays {
            return initialRange(anchor: date)
        }
        return (expandedFirst, expandedLast)
    }
}
