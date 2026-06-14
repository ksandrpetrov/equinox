import EventKit
import Foundation

extension CalendarAccessStatus {
    static func from(_ status: EKAuthorizationStatus) -> CalendarAccessStatus {
        switch status {
        case .fullAccess, .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .writeOnly:
            return .denied
        @unknown default:
            return .notDetermined
        }
    }
}
