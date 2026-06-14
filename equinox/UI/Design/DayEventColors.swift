import AppKit
import SwiftUI

extension DayEvent {
    var calendarColor: NSColor {
        NSColor(
            red: calendarColorRed,
            green: calendarColorGreen,
            blue: calendarColorBlue,
            alpha: calendarColorAlpha
        )
    }

    var swiftUIColor: Color {
        Color(
            red: calendarColorRed,
            green: calendarColorGreen,
            blue: calendarColorBlue,
            opacity: calendarColorAlpha
        )
    }

    static func makeDotColors(for events: [DayEvent]) -> [NSColor]? {
        guard let colors = makeUniqueCalendarEvents(for: events) else { return nil }
        return colors.map(\.calendarColor)
    }

    static func makeSwiftUIDotColors(for events: [DayEvent]) -> [Color]? {
        guard let colors = makeUniqueCalendarEvents(for: events) else { return nil }
        return colors.map(\.swiftUIColor)
    }
}
