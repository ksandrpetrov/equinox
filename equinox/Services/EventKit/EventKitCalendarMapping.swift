import AppKit
import EventKit
import Foundation

/// Shared EventKit/AppKit calendar mapping for `CalendarStore` and `EventKitBridge`.
/// Intentionally not in `Core/` — depends on EventKit and AppKit.
enum EventKitCalendarMapping {
    static func colorHex(_ color: NSColor) -> String {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let red = Int(round(rgb.redComponent * 255))
        let green = Int(round(rgb.greenComponent * 255))
        let blue = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    static func colorHexOrGray(_ color: NSColor?) -> String {
        guard let color else { return "#808080" }
        return colorHex(color)
    }

    static func rgbComponents(from color: NSColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        let rgb = (color.usingColorSpace(.sRGB) ?? color)
        return (rgb.redComponent, rgb.greenComponent, rgb.blueComponent, rgb.alphaComponent)
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
            colorHex: calendar.color.map { colorHex($0) },
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

    static func displayableCalendars(from store: EKEventStore) -> [EKCalendar] {
        displayableCalendarItems(from: store).compactMap { store.calendar(withIdentifier: $0.id) }
    }
}
