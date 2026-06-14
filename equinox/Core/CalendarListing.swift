import Foundation

struct CalendarListItem: Sendable, Equatable {
    let id: String
    let title: String
    let sourceTitle: String
    let sourceIdentifier: String
    let colorHex: String?
    let allowsContentModifications: Bool
    let isSubscribed: Bool
    let type: String
}

enum CalendarListing {
    static func sortCalendarsForDisplay(_ items: [CalendarListItem]) -> [CalendarListItem] {
        items.sorted { lhs, rhs in
            if lhs.sourceIdentifier == rhs.sourceIdentifier {
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            return lhs.sourceTitle.localizedStandardCompare(rhs.sourceTitle) == .orderedAscending
        }
    }

    static func filterDisplayableCalendars(_ items: [CalendarListItem]) -> [CalendarListItem] {
        items.filter { $0.colorHex != nil }
    }
}
