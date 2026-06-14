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
        let components = EventKitCalendarMapping.rgbComponents(from: calendar.color ?? .gray)
        return SelectableCalendar(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            sourceTitle: sourceTitle,
            isSelected: isSelected,
            colorRed: components.red,
            colorGreen: components.green,
            colorBlue: components.blue,
            colorAlpha: components.alpha,
            allowsContentModifications: calendar.allowsContentModifications
        )
    }
}

enum CalendarListEntry: Sendable, Equatable {
    case source(String)
    case calendar(SelectableCalendar)
}
