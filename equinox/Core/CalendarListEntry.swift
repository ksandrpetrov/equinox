import Foundation

struct SelectableCalendar: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let sourceTitle: String
    var isSelected: Bool
    let colorRed: CGFloat
    let colorGreen: CGFloat
    let colorBlue: CGFloat
    let colorAlpha: CGFloat
    let allowsContentModifications: Bool
}

enum CalendarListEntry: Sendable, Equatable {
    case source(String)
    case calendar(SelectableCalendar)
}

enum CalendarListEntryFiltering {
    /// Filters grouped calendar list entries by title query while preserving source headers.
    static func filter(_ entries: [CalendarListEntry], query: String) -> [CalendarListEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        var result: [CalendarListEntry] = []
        var currentSource: String?
        var sourceItems: [CalendarListEntry] = []

        func flushSource() {
            let matching: [CalendarListEntry]
            if currentSource?.localizedCaseInsensitiveContains(trimmed) == true {
                matching = sourceItems
            } else {
                matching = sourceItems.filter { item in
                    guard case .calendar(let calendar) = item else { return false }
                    return calendar.title.localizedCaseInsensitiveContains(trimmed)
                }
            }
            if !matching.isEmpty {
                if let currentSource {
                    result.append(.source(currentSource))
                }
                result.append(contentsOf: matching)
            }
            sourceItems = []
        }

        for item in entries {
            if case .source(let source) = item {
                flushSource()
                currentSource = source
            } else {
                sourceItems.append(item)
            }
        }
        flushSource()
        return result
    }
}
