import Foundation

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
/// Legacy UserDefaults key — literal `"kShowEventDots"` (with prefix) must not change; existing installs rely on it.
let kShowEventDots = "kShowEventDots"
let kShowDaysWithNoEventsInAgenda = "ShowDaysWithNoEventsInAgenda"
let kAgendaHeightRatio = "AgendaHeightRatio"
let kShowMonthBoundaries = "ShowMonthBoundaries"
let kSelectedCalendars = "SelectedCalendars"
let kMcpEnabled = "McpEnabled"
let kPlaudEnabled = "PlaudEnabled"
let kHasSeenShortcutTip = "HasSeenShortcutTip"
let kKeyboardShortcutsMigrationFromMASShortcut = "KeyboardShortcutsMigrationFromMASShortcut"

let kThemePreference = "ThemePreference"
let kBackgroundStyle = "BackgroundStyle"
let kSizePreference = "SizePreference"

let kEquinoxSizePreferenceChanged = Notification.Name("EquinoxSizePreferenceChanged")
let kEquinoxMenuBarAppearanceChanged = Notification.Name("EquinoxMenuBarAppearanceChanged")

enum BackgroundStyle: Int {
    case glass = 0
    case solid = 1
}

enum ThemePreference: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2
}

enum MenuBarIconStyle: Int, CaseIterable {
    case minimal = 0
    case classic = 1
    case compact = 2

    static let clampedRange = 0...2
}
