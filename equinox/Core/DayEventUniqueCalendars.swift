import Foundation

extension DayEvent {
    static func makeUniqueCalendarEvents(for events: [DayEvent]) -> [DayEvent]? {
        guard !events.isEmpty else { return nil }
        var unique: [DayEvent] = []
        var seen = Set<String>()
        for event in events {
            if seen.insert(event.calendarIdentifier).inserted {
                unique.append(event)
                if unique.count == 3 { break }
            }
        }
        return unique
    }
}
