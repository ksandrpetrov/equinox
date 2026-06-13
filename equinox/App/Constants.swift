import Foundation
import EventKit

let kPanelPinned = "PanelPinned"
let kCalendarNumRows = "CalendarNumRows"
/// Whether the pinned floating panel was on screen at last quit, so it can be restored on next launch.
let kPinnedPanelVisible = "PinnedPanelVisible"
let kShowEventDays = "ShowEventDays"
let kShowWeeks = "ShowWeeks"
let kWeekStartDOW = "WeekStartDOW"
let kHighlightedDOWs = "HighlightedDOWs"
/// Sunday (0) and Saturday (6).
let kDefaultHighlightedDOWs = (1 << 0) | (1 << 6)
let kKeyboardShortcut = "GlobalShortcut"
let kMenuBarIconType = "MenuBarIconType"
let kShowMonthInIcon = "ShowMonthInIcon"
let kShowDayOfWeekInIcon = "ShowDayOfWeekInIcon"
let kShowMeetingIndicator = "ShowMeetingIndicator"
let kClockFormat = "ClockFormat"
let kHideIcon = "HideIcon"
let kShowLocation = "ShowLocation"
let kShowEventDots = "kShowEventDots"
let kShowDaysWithNoEventsInAgenda = "ShowDaysWithNoEventsInAgenda"
let kShowEventPopoverOnHover = "ShowEventPopoverOnHover"
let kAgendaHeightRatio = "AgendaHeightRatio"
let kShowMonthBoundaries = "ShowMonthBoundaries"
let kSelectedCalendars = "SelectedCalendars"
let kMcpEnabled = "McpEnabled"
let kHasSeenShortcutTip = "HasSeenShortcutTip"

let kThemePreference = "ThemePreference"
let kBackgroundStyle = "BackgroundStyle"
let kSizePreference = "SizePreference"

let kEquinoxEventsUpdated = Notification.Name("EquinoxEventsUpdated")
let kEquinoxSizePreferenceChanged = Notification.Name("EquinoxSizePreferenceChanged")
let kEquinoxMenuBarAppearanceChanged = Notification.Name("EquinoxMenuBarAppearanceChanged")

enum BackgroundStyle: Int {
    case glass = 0
    case solid = 1
}

enum CalendarAccessStatus: Int, Sendable {
    case authorized = 0
    case denied = 1
    case notDetermined = 2
    case restricted = 3

    var isAuthorized: Bool { self == .authorized }

    var localizedLabel: String {
        switch self {
        case .authorized:
            return String(localized: "Full Access", comment: "Calendar access status")
        case .denied:
            return String(localized: "Denied", comment: "Calendar access status")
        case .notDetermined:
            return String(localized: "Not Determined", comment: "Calendar access status")
        case .restricted:
            return String(localized: "Restricted", comment: "Calendar access status")
        }
    }

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
