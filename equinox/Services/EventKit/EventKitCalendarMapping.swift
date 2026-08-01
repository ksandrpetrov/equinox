import EventKit
import Foundation

/// EventKit calendar mapping for the app. Intentionally not in `Core/` because it depends on EventKit.
enum EventKitCalendarMapping {
    static func colorHex(_ cgColor: CGColor) -> String {
        ColorHex.hex(from: cgColor) ?? "#808080"
    }

    static func rgbComponents(from cgColor: CGColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        let rgba = ColorHex.cgColorComponents(cgColor) ?? ColorHex.RGBA(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        return (rgba.red, rgba.green, rgba.blue, rgba.alpha)
    }

    static func calendarTypeLabel(_ type: EKCalendarType) -> String {
        switch type {
        case .local: return "local"
        case .calDAV: return "caldav"
        case .exchange: return "exchange"
        case .subscription: return "subscription"
        case .birthday: return "birthday"
        @unknown default: return "unknown"
        }
    }

    static func calendarListItem(from calendar: EKCalendar) -> CalendarListItem {
        CalendarListItem(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            sourceTitle: calendar.source.title,
            sourceIdentifier: calendar.source.sourceIdentifier,
            colorHex: calendar.cgColor.map { colorHex($0) },
            allowsContentModifications: calendar.allowsContentModifications,
            isSubscribed: calendar.isSubscribed,
            type: calendarTypeLabel(calendar.type)
        )
    }

    static func displayableCalendarItems(from store: EKEventStore) -> [CalendarListItem] {
        CalendarListing.filterDisplayableCalendars(
            CalendarListing.sortCalendarsForDisplay(
                store.calendars(for: .event).map { calendarListItem(from: $0) }
            )
        )
    }
}
