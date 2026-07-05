import EventKit
import Foundation

extension SelectableCalendar {
    static func from(_ item: CalendarListItem, calendar: EKCalendar, isSelected: Bool) -> SelectableCalendar {
        let components = EventKitCalendarMapping.rgbComponents(
            from: calendar.cgColor ?? CGColor(gray: 0.5, alpha: 1)
        )
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
