import AppKit
import SwiftUI

@Observable
final class PreferencesStore {
    static let shared = PreferencesStore()

    private let defaults = UserDefaults.standard
    private var isLoading = false

    var isPanelPinned: Bool { didSet { persist(isPanelPinned, forKey: kPanelPinned) } }
    var showEventDays: Int { didSet { persist(showEventDays, forKey: kShowEventDays) } }
    var weekStartWeekday: Int { didSet { persist(weekStartWeekday, forKey: kWeekStartDOW) } }
    var highlightedWeekdays: Int { didSet { persist(highlightedWeekdays, forKey: kHighlightedDOWs) } }
    var showWeeks: Bool { didSet { persist(showWeeks, forKey: kShowWeeks) } }
    var showEventDots: Bool { didSet { persist(showEventDots, forKey: kShowEventDots) } }
    var showLocation: Bool { didSet { persist(showLocation, forKey: kShowLocation) } }
    var showDaysWithNoEvents: Bool { didSet { persist(showDaysWithNoEvents, forKey: kShowDaysWithNoEventsInAgenda) } }
    var menuBarIconType: Int { didSet { persist(menuBarIconType, forKey: kMenuBarIconType); notifyMenuBarAppearanceChanged() } }
    var showMonthInIcon: Bool { didSet { persist(showMonthInIcon, forKey: kShowMonthInIcon); notifyMenuBarAppearanceChanged() } }
    var showDayOfWeekInIcon: Bool { didSet { persist(showDayOfWeekInIcon, forKey: kShowDayOfWeekInIcon); notifyMenuBarAppearanceChanged() } }
    var isIconHidden: Bool { didSet { persist(isIconHidden, forKey: kHideIcon); notifyMenuBarAppearanceChanged() } }
    var clockFormat: String? {
        didSet {
            guard !isLoading else { return }
            if let clockFormat { defaults.set(clockFormat, forKey: kClockFormat) }
            else { defaults.removeObject(forKey: kClockFormat) }
            notifyMenuBarAppearanceChanged()
        }
    }
    var showMeetingIndicator: Bool { didSet { persist(showMeetingIndicator, forKey: kShowMeetingIndicator); notifyMenuBarAppearanceChanged() } }
    var themePreference: Int {
        didSet {
            persist(themePreference, forKey: kThemePreference)
            if !isLoading { applyTheme() }
        }
    }
    var sizePreference: Int {
        didSet {
            persist(sizePreference, forKey: kSizePreference)
            if !isLoading {
                NotificationCenter.default.post(name: kEquinoxSizePreferenceChanged, object: nil)
            }
        }
    }
    var backgroundStyle: Int { didSet { persist(backgroundStyle, forKey: kBackgroundStyle) } }
    var calendarRowCount: Int { didSet { persist(calendarRowCount, forKey: kCalendarNumRows) } }
    var showMonthBoundaries: Bool { didSet { persist(showMonthBoundaries, forKey: kShowMonthBoundaries) } }
    var showsDayHoverPreview: Bool { didSet { persist(showsDayHoverPreview, forKey: kShowEventPopoverOnHover) } }
    var agendaHeightRatio: Double { didSet { persist(agendaHeightRatio, forKey: kAgendaHeightRatio) } }
    var isMcpEnabled: Bool { didSet { persist(isMcpEnabled, forKey: kMcpEnabled) } }
    var isPlaudEnabled: Bool { didSet { persist(isPlaudEnabled, forKey: kPlaudEnabled) } }
    var plaudSyncIndexPath: String? {
        didSet {
            guard !isLoading else { return }
            if let plaudSyncIndexPath { defaults.set(plaudSyncIndexPath, forKey: kPlaudSyncIndexPath) }
            else { defaults.removeObject(forKey: kPlaudSyncIndexPath) }
        }
    }
    var plaudSyncIndexBookmark: Data? {
        didSet {
            guard !isLoading else { return }
            if let plaudSyncIndexBookmark { defaults.set(plaudSyncIndexBookmark, forKey: kPlaudSyncIndexBookmark) }
            else { defaults.removeObject(forKey: kPlaudSyncIndexBookmark) }
        }
    }
    var plaudExporterDataPath: String? {
        didSet {
            guard !isLoading else { return }
            if let plaudExporterDataPath { defaults.set(plaudExporterDataPath, forKey: kPlaudExporterDataPath) }
            else { defaults.removeObject(forKey: kPlaudExporterDataPath) }
        }
    }

    private init() {
        isLoading = true
        isPanelPinned = defaults.bool(forKey: kPanelPinned)
        showEventDays = Self.clampedShowEventDays(defaults.integer(forKey: kShowEventDays), hasValue: defaults.object(forKey: kShowEventDays) != nil)
        weekStartWeekday = defaults.integer(forKey: kWeekStartDOW)
        highlightedWeekdays = defaults.integer(forKey: kHighlightedDOWs)
        showWeeks = defaults.bool(forKey: kShowWeeks)
        showEventDots = defaults.bool(forKey: kShowEventDots)
        showLocation = defaults.bool(forKey: kShowLocation)
        showDaysWithNoEvents = defaults.bool(forKey: kShowDaysWithNoEventsInAgenda)
        let rawMenuBarIconType = defaults.integer(forKey: kMenuBarIconType)
        menuBarIconType = Self.clampedMenuBarIconType(rawMenuBarIconType)
        showMonthInIcon = defaults.bool(forKey: kShowMonthInIcon)
        showDayOfWeekInIcon = defaults.bool(forKey: kShowDayOfWeekInIcon)
        isIconHidden = defaults.bool(forKey: kHideIcon)
        clockFormat = defaults.string(forKey: kClockFormat)
        showMeetingIndicator = defaults.bool(forKey: kShowMeetingIndicator)
        themePreference = defaults.integer(forKey: kThemePreference)
        sizePreference = defaults.integer(forKey: kSizePreference)
        backgroundStyle = defaults.integer(forKey: kBackgroundStyle)
        calendarRowCount = Self.clampedCalendarNumRows(defaults.integer(forKey: kCalendarNumRows))
        showMonthBoundaries = defaults.bool(forKey: kShowMonthBoundaries)
        showsDayHoverPreview = defaults.bool(forKey: kShowEventPopoverOnHover)
        agendaHeightRatio = Self.clampedAgendaHeightRatio(defaults.double(forKey: kAgendaHeightRatio))
        isMcpEnabled = defaults.bool(forKey: kMcpEnabled)
        isPlaudEnabled = defaults.bool(forKey: kPlaudEnabled)
        plaudSyncIndexPath = defaults.string(forKey: kPlaudSyncIndexPath)
        plaudSyncIndexBookmark = defaults.data(forKey: kPlaudSyncIndexBookmark)
        plaudExporterDataPath = defaults.string(forKey: kPlaudExporterDataPath)
        isLoading = false
        if rawMenuBarIconType != menuBarIconType {
            defaults.set(menuBarIconType, forKey: kMenuBarIconType)
        }
    }

    private func persist(_ value: some Any, forKey key: String) {
        guard !isLoading else { return }
        defaults.set(value, forKey: key)
    }

    private func notifyMenuBarAppearanceChanged() {
        guard !isLoading else { return }
        NotificationCenter.default.post(name: kEquinoxMenuBarAppearanceChanged, object: nil)
    }

    private static func clampedMenuBarIconType(_ value: Int) -> Int {
        min(max(value, 0), 2)
    }

    private static func clampedShowEventDays(_ value: Int, hasValue: Bool) -> Int {
        if !hasValue { return 7 }
        return min(max(value, 0), 9)
    }

    private static func clampedCalendarNumRows(_ rows: Int) -> Int {
        min(max(rows == 0 ? 6 : rows, 6), 10)
    }

    private static func clampedAgendaHeightRatio(_ ratio: Double) -> Double {
        ratio == 0 ? 0.35 : min(max(ratio, 0.15), 0.65)
    }

    func applyTheme() {
        switch themePreference {
        case 1: NSApp.appearance = NSAppearance(named: .aqua)
        case 2: NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }

    func resetToDefaults() {
        isLoading = true
        let defaults = PreferencesStore.registeredDefaultValues()
        for (key, value) in defaults {
            UserDefaults.standard.set(value, forKey: key)
        }
        CalendarSelectionStorage.clearSelection()
        reloadFromDefaults()
        isLoading = false
        applyTheme()
        NotificationCenter.default.post(name: kEquinoxSizePreferenceChanged, object: nil)
        notifyMenuBarAppearanceChanged()
    }

    static func registeredDefaultValues() -> [String: Any] {
        let cal = Calendar.autoupdatingCurrent
        let weekStart = min(max(cal.firstWeekday - 1, 0), 6)
        return [
            kPanelPinned: false,
            kShowWeeks: false,
            kHighlightedDOWs: kDefaultHighlightedDOWs,
            kShowEventDays: 7,
            kWeekStartDOW: weekStart,
            kShowMonthInIcon: false,
            kShowDayOfWeekInIcon: false,
            kShowEventDots: true,
            kThemePreference: 0,
            kBackgroundStyle: BackgroundStyle.glass.rawValue,
            kSizePreference: SizePreference.medium.rawValue,
            kHideIcon: false,
            kShowLocation: false,
            kShowMonthBoundaries: true,
            kAgendaHeightRatio: 0.35,
            kHasSeenShortcutTip: false,
            kShowMeetingIndicator: false,
            kMenuBarIconType: 0,
            kShowDaysWithNoEventsInAgenda: false,
            kShowEventPopoverOnHover: false,
            kMcpEnabled: false,
            kPlaudEnabled: false,
            kCalendarNumRows: 6,
        ]
    }

    private func reloadFromDefaults() {
        isPanelPinned = defaults.bool(forKey: kPanelPinned)
        showEventDays = Self.clampedShowEventDays(defaults.integer(forKey: kShowEventDays), hasValue: defaults.object(forKey: kShowEventDays) != nil)
        weekStartWeekday = defaults.integer(forKey: kWeekStartDOW)
        highlightedWeekdays = defaults.integer(forKey: kHighlightedDOWs)
        showWeeks = defaults.bool(forKey: kShowWeeks)
        showEventDots = defaults.bool(forKey: kShowEventDots)
        showLocation = defaults.bool(forKey: kShowLocation)
        showDaysWithNoEvents = defaults.bool(forKey: kShowDaysWithNoEventsInAgenda)
        menuBarIconType = Self.clampedMenuBarIconType(defaults.integer(forKey: kMenuBarIconType))
        showMonthInIcon = defaults.bool(forKey: kShowMonthInIcon)
        showDayOfWeekInIcon = defaults.bool(forKey: kShowDayOfWeekInIcon)
        isIconHidden = defaults.bool(forKey: kHideIcon)
        clockFormat = defaults.string(forKey: kClockFormat)
        showMeetingIndicator = defaults.bool(forKey: kShowMeetingIndicator)
        themePreference = defaults.integer(forKey: kThemePreference)
        sizePreference = defaults.integer(forKey: kSizePreference)
        backgroundStyle = defaults.integer(forKey: kBackgroundStyle)
        calendarRowCount = Self.clampedCalendarNumRows(defaults.integer(forKey: kCalendarNumRows))
        showMonthBoundaries = defaults.bool(forKey: kShowMonthBoundaries)
        showsDayHoverPreview = defaults.bool(forKey: kShowEventPopoverOnHover)
        agendaHeightRatio = Self.clampedAgendaHeightRatio(defaults.double(forKey: kAgendaHeightRatio))
        isMcpEnabled = defaults.bool(forKey: kMcpEnabled)
        isPlaudEnabled = defaults.bool(forKey: kPlaudEnabled)
        plaudSyncIndexPath = defaults.string(forKey: kPlaudSyncIndexPath)
        plaudSyncIndexBookmark = defaults.data(forKey: kPlaudSyncIndexBookmark)
        plaudExporterDataPath = defaults.string(forKey: kPlaudExporterDataPath)
    }

    func isWeekdayHighlighted(_ column: Int, weekStartWeekday: Int) -> Bool {
        let dow = weekdayForColumn(startDOW: weekStartWeekday, col: column)
        return (highlightedWeekdays & (1 << dow)) != 0
    }
}
