import EventKit
import Foundation

/// KVC access to `EKEvent.participationStatus` — not a public Apple API; may break on macOS upgrades.
enum EventParticipationAccessor {
    static func rawValue(for event: EKEvent) -> Int? {
        event.value(forKey: "participationStatus") as? Int
    }

    static func apply(_ status: EventParticipationStatus, to event: EKEvent) throws {
        event.setValue(status.rawValue, forKey: "participationStatus")
    }
}

extension EKEvent {
    var equinoxParticipationRawValue: Int? {
        EventParticipationAccessor.rawValue(for: self)
    }
}
