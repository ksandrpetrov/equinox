import AppKit
import EventKit
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

    static func from(calendar: EKCalendar, sourceTitle: String, isSelected: Bool) -> SelectableCalendar {
        from(
            EventKitCalendarMapping.calendarListItem(from: calendar),
            calendar: calendar,
            isSelected: isSelected
        )
    }

    static func from(_ item: CalendarListItem, calendar: EKCalendar, isSelected: Bool) -> SelectableCalendar {
        let components = EventKitCalendarMapping.rgbComponents(from: calendar.color ?? .gray)
        return SelectableCalendar(
            id: item.id,
            title: item.title,
            sourceTitle: item.sourceTitle,
            isSelected: isSelected,
            colorRed: components.red,
            colorGreen: components.green,
            colorBlue: components.blue,
            colorAlpha: components.alpha,
            allowsContentModifications: item.allowsContentModifications
        )
    }
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
        let lowered = trimmed.lowercased()
        var result: [CalendarListEntry] = []
        var currentSource: String?
        var sourceItems: [CalendarListEntry] = []

        func flushSource() {
            guard currentSource != nil else { return }
            let matching = sourceItems.filter { item in
                if case .calendar(let cal) = item {
                    return cal.title.lowercased().contains(lowered)
                }
                return false
            }
            if !matching.isEmpty, let source = currentSource {
                result.append(.source(source))
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
        return result.isEmpty && !entries.isEmpty ? entries : result
    }
}
