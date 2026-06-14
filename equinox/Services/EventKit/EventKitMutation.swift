import EventKit
import Foundation

/// Shared EventKit mutation helpers for `CalendarStore` and `EventKitBridge`.
/// GUI-only fields (recurrence, alarms, timezone) stay in `applyCreate(from:)`.
enum EventKitMutation {
    static func applyCreate(from draft: NewEventDraft, to event: EKEvent, calendar: EKCalendar) {
        event.title = draft.title
        event.location = draft.location.isEmpty ? nil : draft.location
        event.url = draft.url
        event.isAllDay = draft.isAllDay
        event.startDate = draft.startDate
        event.endDate = draft.endDate
        event.calendar = calendar
        event.notes = draft.notes
        event.timeZone = draft.isAllDay ? nil : TimeZone.current

        if let recurrence = draft.recurrence {
            event.recurrenceRules = [recurrenceRule(from: recurrence)]
        }

        if let offset = draft.alertOffset {
            for alarm in event.alarms ?? [] { event.removeAlarm(alarm) }
            event.addAlarm(EKAlarm(relativeOffset: offset))
        }
    }

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

    private static func recurrenceRule(from draft: RecurrenceDraft) -> EKRecurrenceRule {
        let frequency: EKRecurrenceFrequency
        var interval = 1
        switch draft.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .biweekly: frequency = .weekly; interval = 2
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        }
        let end = draft.endDate.map { EKRecurrenceEnd(end: $0) }
        return EKRecurrenceRule(recurrenceWith: frequency, interval: interval, end: end)
    }
}
