import AppKit

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
            if !isLoading {
                Task { @MainActor in applyTheme() }
            }
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
    var agendaHeightRatio: Double { didSet { persist(agendaHeightRatio, forKey: kAgendaHeightRatio) } }
    var isMcpEnabled: Bool { didSet { persist(isMcpEnabled, forKey: kMcpEnabled) } }
    var isPlaudEnabled: Bool { didSet { persist(isPlaudEnabled, forKey: kPlaudEnabled) } }
    var hasSeenShortcutTip: Bool { didSet { persist(hasSeenShortcutTip, forKey: kHasSeenShortcutTip) } }

    private struct StoredValues {
        var isPanelPinned: Bool
        var showEventDays: Int
        var weekStartWeekday: Int
        var highlightedWeekdays: Int
        var showWeeks: Bool
        var showEventDots: Bool
        var showLocation: Bool
        var showDaysWithNoEvents: Bool
        var menuBarIconType: Int
        var showMonthInIcon: Bool
        var showDayOfWeekInIcon: Bool
        var isIconHidden: Bool
        var clockFormat: String?
        var showMeetingIndicator: Bool
        var themePreference: Int
        var sizePreference: Int
        var backgroundStyle: Int
        var calendarRowCount: Int
        var showMonthBoundaries: Bool
        var agendaHeightRatio: Double
        var isMcpEnabled: Bool
        var isPlaudEnabled: Bool
        var hasSeenShortcutTip: Bool
    }

    private init() {
        isLoading = true
        isPanelPinned = false
        showEventDays = 7
        weekStartWeekday = 0
        highlightedWeekdays = 0
        showWeeks = false
        showEventDots = true
        showLocation = false
        showDaysWithNoEvents = false
        menuBarIconType = 0
        showMonthInIcon = false
        showDayOfWeekInIcon = false
        isIconHidden = false
        clockFormat = nil
        showMeetingIndicator = false
        themePreference = 0
        sizePreference = SizePreference.medium.rawValue
        backgroundStyle = BackgroundStyle.glass.rawValue
        calendarRowCount = 6
        showMonthBoundaries = true
        agendaHeightRatio = 0.35
        isMcpEnabled = false
        isPlaudEnabled = false
        hasSeenShortcutTip = false
        let rawMenuBarIconType = UserDefaults.standard.integer(forKey: kMenuBarIconType)
        applyValues(Self.readValues(from: UserDefaults.standard))
        isLoading = false
        if rawMenuBarIconType != menuBarIconType {
            UserDefaults.standard.set(menuBarIconType, forKey: kMenuBarIconType)
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

    @MainActor
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
        Task { @MainActor in applyTheme() }
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
            kMcpEnabled: false,
            kPlaudEnabled: false,
            kCalendarNumRows: 6,
        ]
    }

    private static func readValues(from defaults: UserDefaults) -> StoredValues {
        StoredValues(
            isPanelPinned: defaults.bool(forKey: kPanelPinned),
            showEventDays: clampedShowEventDays(defaults.integer(forKey: kShowEventDays), hasValue: defaults.object(forKey: kShowEventDays) != nil),
            weekStartWeekday: defaults.integer(forKey: kWeekStartDOW),
            highlightedWeekdays: defaults.integer(forKey: kHighlightedDOWs),
            showWeeks: defaults.bool(forKey: kShowWeeks),
            showEventDots: defaults.bool(forKey: kShowEventDots),
            showLocation: defaults.bool(forKey: kShowLocation),
            showDaysWithNoEvents: defaults.bool(forKey: kShowDaysWithNoEventsInAgenda),
            menuBarIconType: clampedMenuBarIconType(defaults.integer(forKey: kMenuBarIconType)),
            showMonthInIcon: defaults.bool(forKey: kShowMonthInIcon),
            showDayOfWeekInIcon: defaults.bool(forKey: kShowDayOfWeekInIcon),
            isIconHidden: defaults.bool(forKey: kHideIcon),
            clockFormat: defaults.string(forKey: kClockFormat),
            showMeetingIndicator: defaults.bool(forKey: kShowMeetingIndicator),
            themePreference: defaults.integer(forKey: kThemePreference),
            sizePreference: defaults.integer(forKey: kSizePreference),
            backgroundStyle: defaults.integer(forKey: kBackgroundStyle),
            calendarRowCount: clampedCalendarNumRows(defaults.integer(forKey: kCalendarNumRows)),
            showMonthBoundaries: defaults.bool(forKey: kShowMonthBoundaries),
            agendaHeightRatio: clampedAgendaHeightRatio(defaults.double(forKey: kAgendaHeightRatio)),
            isMcpEnabled: defaults.bool(forKey: kMcpEnabled),
            isPlaudEnabled: defaults.bool(forKey: kPlaudEnabled),
            hasSeenShortcutTip: defaults.bool(forKey: kHasSeenShortcutTip)
        )
    }

    private func applyValues(_ values: StoredValues) {
        isPanelPinned = values.isPanelPinned
        showEventDays = values.showEventDays
        weekStartWeekday = values.weekStartWeekday
        highlightedWeekdays = values.highlightedWeekdays
        showWeeks = values.showWeeks
        showEventDots = values.showEventDots
        showLocation = values.showLocation
        showDaysWithNoEvents = values.showDaysWithNoEvents
        menuBarIconType = values.menuBarIconType
        showMonthInIcon = values.showMonthInIcon
        showDayOfWeekInIcon = values.showDayOfWeekInIcon
        isIconHidden = values.isIconHidden
        clockFormat = values.clockFormat
        showMeetingIndicator = values.showMeetingIndicator
        themePreference = values.themePreference
        sizePreference = values.sizePreference
        backgroundStyle = values.backgroundStyle
        calendarRowCount = values.calendarRowCount
        showMonthBoundaries = values.showMonthBoundaries
        agendaHeightRatio = values.agendaHeightRatio
        isMcpEnabled = values.isMcpEnabled
        isPlaudEnabled = values.isPlaudEnabled
        hasSeenShortcutTip = values.hasSeenShortcutTip
    }

    private func reloadFromDefaults() {
        applyValues(Self.readValues(from: defaults))
    }

    func isWeekdayHighlighted(_ column: Int, weekStartWeekday: Int) -> Bool {
        let dow = weekdayForColumn(startDOW: weekStartWeekday, col: column)
        return (highlightedWeekdays & (1 << dow)) != 0
    }
}
