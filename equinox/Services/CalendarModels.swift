import AppKit
import EventKit
import Foundation
import SwiftUI

struct DayEvent: Identifiable, Sendable, Equatable {
    let id: String
    let eventIdentifier: String?
    let calendarItemIdentifier: String
    let title: String
    let location: String?
    let notes: String?
    let url: URL?
    let startDate: Date
    let endDate: Date
    let isEventAllDay: Bool
    let isFirstDayOfSpan: Bool
    let isLastDayOfSpan: Bool
    let isSlotAllDay: Bool
    let joinURL: URL?
    let calendarIdentifier: String
    let calendarTitle: String
    let calendarColorRed: CGFloat
    let calendarColorGreen: CGFloat
    let calendarColorBlue: CGFloat
    let calendarColorAlpha: CGFloat
    let allowsContentModifications: Bool
    let hasAttendees: Bool
    let participationStatus: EventParticipationStatus?

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

    var displaysAsAllDay: Bool { isSlotAllDay }

    var showsRSVPControls: Bool { hasAttendees }

    static func from(
        event: EKEvent,
        slot: EventDaySlot,
        joinURL: URL?,
        dayKey: Date
    ) -> DayEvent {
        let color = event.calendar.color ?? .gray
        let eventID = event.eventIdentifier
        let syntheticID: String
        if let eventID {
            syntheticID = "\(dayKey.timeIntervalSince1970)-\(eventID)"
        } else {
            syntheticID = "\(dayKey.timeIntervalSince1970)-\(event.calendarItemIdentifier)-\(event.startDate.timeIntervalSince1970)"
        }
        return DayEvent(
            id: syntheticID,
            eventIdentifier: event.eventIdentifier,
            calendarItemIdentifier: event.calendarItemIdentifier,
            title: event.title ?? "",
            location: event.location,
            notes: event.notes,
            url: event.url,
            startDate: event.startDate,
            endDate: event.endDate,
            isEventAllDay: event.isAllDay,
            isFirstDayOfSpan: slot.isFirstDayOfSpan,
            isLastDayOfSpan: slot.isLastDayOfSpan,
            isSlotAllDay: slot.displaysAsAllDay,
            joinURL: joinURL,
            calendarIdentifier: event.calendar.calendarIdentifier,
            calendarTitle: event.calendar.title,
            calendarColorRed: color.redComponent,
            calendarColorGreen: color.greenComponent,
            calendarColorBlue: color.blueComponent,
            calendarColorAlpha: color.alphaComponent,
            allowsContentModifications: event.calendar.allowsContentModifications,
            hasAttendees: event.hasAttendees,
            participationStatus: event.equinoxParticipationStatus
        )
    }
}

private extension EKEvent {
    var equinoxParticipationStatus: EventParticipationStatus? {
        EventParticipationMapping.status(
            hasAttendees: hasAttendees,
            eventKitRawValue: value(forKey: "participationStatus") as? Int
        )
    }
}

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

    var color: NSColor {
        NSColor(red: colorRed, green: colorGreen, blue: colorBlue, alpha: colorAlpha)
    }

    var swiftUIColor: Color {
        Color(red: colorRed, green: colorGreen, blue: colorBlue, opacity: colorAlpha)
    }

    static func from(calendar: EKCalendar, sourceTitle: String, isSelected: Bool) -> SelectableCalendar {
        let color = calendar.color ?? .gray
        return SelectableCalendar(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            sourceTitle: sourceTitle,
            isSelected: isSelected,
            colorRed: color.redComponent,
            colorGreen: color.greenComponent,
            colorBlue: color.blueComponent,
            colorAlpha: color.alphaComponent,
            allowsContentModifications: calendar.allowsContentModifications
        )
    }
}

enum CalendarListEntry: Sendable, Equatable {
    case source(String)
    case calendar(SelectableCalendar)
}

enum RecurrenceFrequency: Sendable, Equatable {
    case daily
    case weekly
    case biweekly
    case monthly
    case yearly
}

struct RecurrenceDraft: Sendable, Equatable {
    let frequency: RecurrenceFrequency
    let endDate: Date?
}

struct NewEventDraft: Sendable, Equatable {
    var title: String
    var location: String
    var url: URL?
    var notes: String?
    var isAllDay: Bool
    var startDate: Date
    var endDate: Date
    var calendarIdentifier: String
    var recurrence: RecurrenceDraft?
    /// Relative alarm offset in seconds (negative = before start). `nil` = no alert.
    var alertOffset: TimeInterval?
}

enum CalendarSelectionStorage {
    static func loadSelectedIDs() -> [String] {
        UserDefaults.standard.array(forKey: kSelectedCalendars) as? [String] ?? []
    }

    static func saveSelectedIDs(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: kSelectedCalendars)
    }

    static func clearSelection() {
        UserDefaults.standard.removeObject(forKey: kSelectedCalendars)
    }
}
