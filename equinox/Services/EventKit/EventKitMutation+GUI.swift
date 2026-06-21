import EventKit
import Foundation

extension EventKitMutation {
    /// GUI-only create path with recurrence, alarms, and timezone.
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
