import Foundation

enum CalendarAccessStatus: Int, Sendable {
    case authorized = 0
    case denied = 1
    case notDetermined = 2
    case restricted = 3

    var isAuthorized: Bool { self == .authorized }

    var localizedLabel: String {
        switch self {
        case .authorized:
            return String(localized: "Full Access", bundle: .equinox, comment: "Calendar access status")
        case .denied:
            return String(localized: "Denied", bundle: .equinox, comment: "Calendar access status")
        case .notDetermined:
            return String(localized: "Not Determined", bundle: .equinox, comment: "Calendar access status")
        case .restricted:
            return String(localized: "Restricted", bundle: .equinox, comment: "Calendar access status")
        }
    }
}
