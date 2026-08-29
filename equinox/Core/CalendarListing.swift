import Foundation

struct CalendarListItem: Sendable, Equatable {
    let id: String
    let title: String
    let sourceTitle: String
    let sourceIdentifier: String
    let colorHex: String
    let allowsContentModifications: Bool
    let isSubscribed: Bool
    let type: String
}

enum CalendarListing {
    static func sortCalendarsForDisplay(_ items: [CalendarListItem]) -> [CalendarListItem] {
        items.sorted { lhs, rhs in
            let sourceComparison = lhs.sourceTitle.localizedStandardCompare(rhs.sourceTitle)
            if sourceComparison != .orderedSame {
                return sourceComparison == .orderedAscending
            }
            if lhs.sourceIdentifier != rhs.sourceIdentifier {
                return lhs.sourceIdentifier < rhs.sourceIdentifier
            }
            let titleComparison = lhs.title.localizedStandardCompare(rhs.title)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }
            if lhs.title != rhs.title {
                return lhs.title < rhs.title
            }
            return lhs.id < rhs.id
        }
    }
}
