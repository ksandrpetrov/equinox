import AppKit
import EventKit
import Foundation

extension SelectableCalendar {
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
