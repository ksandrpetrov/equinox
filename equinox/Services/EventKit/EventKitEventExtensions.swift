import EventKit
import Foundation

extension EKEvent {
    var equinoxParticipationRawValue: Int? {
        attendees?.first(where: \.isCurrentUser)?.participantStatus.rawValue
    }
}
