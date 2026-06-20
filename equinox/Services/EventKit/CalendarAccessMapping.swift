import EventKit
import Foundation

enum CalendarAccessMapping {
    static func bridgeAuthorizationStatus() -> (label: String, granted: Bool) {
        let status = EKEventStore.authorizationStatus(for: .event)
        return (bridgeLabel(for: status), bridgeGranted(for: status))
    }

    static func bridgeLabel(for status: EKAuthorizationStatus) -> String {
        switch status {
        case .fullAccess, .authorized:
            return "full_access"
        case .writeOnly:
            return "write_only"
        case .notDetermined:
            return "not_determined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        @unknown default:
            return "unknown"
        }
    }

    static func bridgeGranted(for status: EKAuthorizationStatus) -> Bool {
        switch status {
        case .fullAccess, .authorized:
            return true
        default:
            return false
        }
    }
}

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
