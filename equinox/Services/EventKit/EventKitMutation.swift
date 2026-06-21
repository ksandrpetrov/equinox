import EventKit
import Foundation

/// Shared EventKit mutation helpers for `CalendarStore` and `EventKitBridge`.
/// GUI-only create path lives in `EventKitMutation+GUI.swift`.
enum EventKitMutation {
    static func applyBridgeCreate(
        title: String,
        start: Date,
        end: Date,
        calendar: EKCalendar,
        allDay: Bool,
        location: String?,
        notes: String?,
        url: URL?,
        to event: EKEvent
    ) {
        event.calendar = calendar
        event.title = title
        event.startDate = start
        event.endDate = end
        event.isAllDay = allDay
        event.location = location
        event.notes = notes
        event.url = url
    }

    static func applyBridgeUpdate(
        title: String?,
        start: Date?,
        end: Date?,
        allDay: Bool?,
        location: String?,
        notes: String?,
        url: URL?,
        calendar: EKCalendar?,
        to event: EKEvent
    ) {
        if let title {
            event.title = title
        }
        if let start {
            event.startDate = start
        }
        if let end {
            event.endDate = end
        }
        if let allDay {
            event.isAllDay = allDay
        }
        if let location {
            event.location = location
        }
        if let notes {
            event.notes = notes
        }
        if let url {
            event.url = url
        }
        if let calendar {
            event.calendar = calendar
        }
    }
}
