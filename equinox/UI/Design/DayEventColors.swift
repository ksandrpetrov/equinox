import SwiftUI

extension DayEvent {
    var swiftUIColor: Color {
        Color(
            red: calendarColorRed,
            green: calendarColorGreen,
            blue: calendarColorBlue,
            opacity: calendarColorAlpha
        )
    }

    static func makeSwiftUIDotColors(for events: [DayEvent]) -> [Color]? {
        guard let colors = makeUniqueCalendarEvents(for: events) else { return nil }
        return colors.map(\.swiftUIColor)
    }
}
