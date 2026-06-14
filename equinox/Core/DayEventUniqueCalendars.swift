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
        switch unique.count {
        case 0: return nil
        case 1: return [unique[0]]
        case 2: return [unique[0], unique[1]]
        default: return [unique[0], unique[1], unique[2]]
        }
    }
}
