import EventKit
import Foundation

enum CalendarAccessMapping {
    enum AccessKind: Equatable {
        case fullAccess
        case writeOnly
        case notDetermined
        case restricted
        case denied
        case unknown
    }

    static func accessKind(for status: EKAuthorizationStatus) -> AccessKind {
        switch status {
        case .fullAccess, .authorized:
            return .fullAccess
        case .writeOnly:
            return .writeOnly
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        @unknown default:
            return .unknown
        }
    }

    static func bridgeAuthorizationStatus() -> (label: String, granted: Bool) {
        let kind = accessKind(for: EKEventStore.authorizationStatus(for: .event))
        return (bridgeLabel(for: kind), kind == .fullAccess)
    }

    static func guiAccessStatus() -> CalendarAccessStatus {
        guiStatus(for: accessKind(for: EKEventStore.authorizationStatus(for: .event)))
    }

    static func guiStatus(for kind: AccessKind) -> CalendarAccessStatus {
        switch kind {
        case .fullAccess:
            return .authorized
        case .denied, .writeOnly:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .unknown:
            return .notDetermined
        }
    }

    static func bridgeLabel(for kind: AccessKind) -> String {
        switch kind {
        case .fullAccess:
            return "full_access"
        case .writeOnly:
            return "write_only"
        case .notDetermined:
            return "not_determined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .unknown:
            return "unknown"
        }
    }

    static func bridgeLabel(for status: EKAuthorizationStatus) -> String {
        bridgeLabel(for: accessKind(for: status))
    }
}

extension CalendarAccessStatus {
    static func from(_ status: EKAuthorizationStatus) -> CalendarAccessStatus {
        CalendarAccessMapping.guiStatus(for: CalendarAccessMapping.accessKind(for: status))
    }
}
