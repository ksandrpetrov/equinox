import AppKit

@Observable @MainActor
final class PreferencesStore {
    static let shared = PreferencesStore()

    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private var isLoading = true

    var isPanelPinned = false { didSet { persist(isPanelPinned, forKey: kPanelPinned) } }
    var showEventDays = 7 { didSet { persist(showEventDays, forKey: kShowEventDays) } }
    var weekStartWeekday: Int = 0 {
        didSet {
            persist(weekStartWeekday, forKey: kWeekStartDOW)
            if !isLoading { notifyVisibleGridPreferencesChanged() }
        }
    }
    var highlightedWeekdays = 0 { didSet { persist(highlightedWeekdays, forKey: kHighlightedDOWs) } }
    var showWeeks = false { didSet { persist(showWeeks, forKey: kShowWeeks) } }
    var showEventDots = true { didSet { persist(showEventDots, forKey: kShowEventDots) } }
    var showLocation = false { didSet { persist(showLocation, forKey: kShowLocation) } }
    var showDaysWithNoEvents = false { didSet { persist(showDaysWithNoEvents, forKey: kShowDaysWithNoEventsInAgenda) } }
    var menuBarIconType = MenuBarIconStyle.minimal.rawValue {
        didSet {
            persist(menuBarIconType, forKey: kMenuBarIconType)
            notifyMenuBarAppearanceChanged()
        }
    }
    var showMonthInIcon = false {
        didSet {
            persist(showMonthInIcon, forKey: kShowMonthInIcon)
            notifyMenuBarAppearanceChanged()
        }
    }
    var showDayOfWeekInIcon = false {
        didSet {
            persist(showDayOfWeekInIcon, forKey: kShowDayOfWeekInIcon)
            notifyMenuBarAppearanceChanged()
        }
    }
    var isIconHidden = false {
        didSet {
            persist(isIconHidden, forKey: kHideIcon)
            notifyMenuBarAppearanceChanged()
        }
    }
    var clockFormat: String? = nil {
        didSet {
            guard !isLoading else { return }
            if let clockFormat { defaults.set(clockFormat, forKey: kClockFormat) }
            else { defaults.removeObject(forKey: kClockFormat) }
            notifyMenuBarAppearanceChanged()
        }
    }
    var showMeetingIndicator = false {
        didSet {
            persist(showMeetingIndicator, forKey: kShowMeetingIndicator)
            notifyMenuBarAppearanceChanged()
        }
    }
    var themePreference = ThemePreference.system.rawValue {
        didSet {
            persist(themePreference, forKey: kThemePreference)
            if !isLoading {
                Task { @MainActor in applyTheme() }
            }
        }
    }
    var sizePreference = SizePreference.medium.rawValue {
        didSet {
            persist(sizePreference, forKey: kSizePreference)
            if !isLoading {
                notificationCenter.post(name: kEquinoxSizePreferenceChanged, object: nil)
            }
        }
    }
    var backgroundStyle = BackgroundStyle.glass.rawValue {
        didSet { persist(backgroundStyle, forKey: kBackgroundStyle) }
    }
    var calendarRowCount: Int = 6 {
        didSet {
            persist(calendarRowCount, forKey: kCalendarNumRows)
            if !isLoading { notifyVisibleGridPreferencesChanged() }
        }
    }
    var showMonthBoundaries = true {
        didSet { persist(showMonthBoundaries, forKey: kShowMonthBoundaries) }
    }
    var agendaHeightRatio = 0.35 {
        didSet { persist(agendaHeightRatio, forKey: kAgendaHeightRatio) }
    }
    var isPlaudEnabled = false { didSet { persist(isPlaudEnabled, forKey: kPlaudEnabled) } }
    var hasSeenShortcutTip = false { didSet { persist(hasSeenShortcutTip, forKey: kHasSeenShortcutTip) } }

    /// Called when `weekStartWeekday` or `calendarRowCount` changes (grid fetch range must refresh).
    var onVisibleGridPreferencesChanged: (() -> Void)?

    init(
        defaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default
    ) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
        defaults.register(defaults: Self.registeredDefaultValues())
        loadFromDefaults()
        isLoading = false
    }

    private func persist(_ value: some Any, forKey key: String) {
        guard !isLoading else { return }
        defaults.set(value, forKey: key)
    }

    private func notifyMenuBarAppearanceChanged() {
        guard !isLoading else { return }
        notificationCenter.post(name: kEquinoxMenuBarAppearanceChanged, object: nil)
    }

    private func notifyVisibleGridPreferencesChanged() {
        onVisibleGridPreferencesChanged?()
    }

    private static func clampedMenuBarIconType(_ value: Int) -> Int {
        min(max(value, MenuBarIconStyle.clampedRange.lowerBound), MenuBarIconStyle.clampedRange.upperBound)
    }

    private static func clampedShowEventDays(_ value: Int) -> Int {
        return min(max(value, 0), 9)
    }

    private static func clampedCalendarNumRows(_ rows: Int) -> Int {
        min(max(rows == 0 ? 6 : rows, 6), 10)
    }

    private static func clampedAgendaHeightRatio(_ ratio: Double) -> Double {
        guard ratio.isFinite, ratio != 0 else { return 0.35 }
        return min(max(ratio, 0.15), 0.65)
    }

    @MainActor
    func applyTheme() {
        switch ThemePreference(rawValue: themePreference) ?? .system {
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system: NSApp.appearance = nil
        }
    }

    func resetToDefaults() {
        isLoading = true
        for (key, value) in Self.registeredDefaultValues() {
            defaults.set(value, forKey: key)
        }
        defaults.removeObject(forKey: kClockFormat)
        CalendarSelectionStorage.clearSelection(from: defaults)
        loadFromDefaults()
        isLoading = false
        Task { @MainActor in applyTheme() }
        notificationCenter.post(name: kEquinoxSizePreferenceChanged, object: nil)
        notifyMenuBarAppearanceChanged()
    }

    nonisolated static func registeredDefaultValues() -> [String: Any] {
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
            kPlaudEnabled: false,
            kCalendarNumRows: 6,
        ]
    }

    private func loadFromDefaults() {
        isPanelPinned = defaults.bool(forKey: kPanelPinned)
        showEventDays = normalizedInteger(forKey: kShowEventDays, using: Self.clampedShowEventDays)
        weekStartWeekday = normalizedInteger(forKey: kWeekStartDOW) { min(max($0, 0), 6) }
        highlightedWeekdays = normalizedInteger(forKey: kHighlightedDOWs) { $0 & 0x7F }
        showWeeks = defaults.bool(forKey: kShowWeeks)
        showEventDots = defaults.bool(forKey: kShowEventDots)
        showLocation = defaults.bool(forKey: kShowLocation)
        showDaysWithNoEvents = defaults.bool(forKey: kShowDaysWithNoEventsInAgenda)
        menuBarIconType = normalizedInteger(forKey: kMenuBarIconType, using: Self.clampedMenuBarIconType)
        showMonthInIcon = defaults.bool(forKey: kShowMonthInIcon)
        showDayOfWeekInIcon = defaults.bool(forKey: kShowDayOfWeekInIcon)
        isIconHidden = defaults.bool(forKey: kHideIcon)
        clockFormat = defaults.string(forKey: kClockFormat)
        showMeetingIndicator = defaults.bool(forKey: kShowMeetingIndicator)
        themePreference = normalizedInteger(forKey: kThemePreference) {
            ThemePreference(rawValue: $0)?.rawValue ?? ThemePreference.system.rawValue
        }
        sizePreference = normalizedInteger(forKey: kSizePreference) {
            SizePreference(rawValue: $0)?.rawValue ?? SizePreference.medium.rawValue
        }
        backgroundStyle = normalizedInteger(forKey: kBackgroundStyle) {
            BackgroundStyle(rawValue: $0)?.rawValue ?? BackgroundStyle.glass.rawValue
        }
        calendarRowCount = normalizedInteger(forKey: kCalendarNumRows, using: Self.clampedCalendarNumRows)
        showMonthBoundaries = defaults.bool(forKey: kShowMonthBoundaries)
        agendaHeightRatio = normalizedDouble(
            forKey: kAgendaHeightRatio,
            using: Self.clampedAgendaHeightRatio
        )
        isPlaudEnabled = defaults.bool(forKey: kPlaudEnabled)
        hasSeenShortcutTip = defaults.bool(forKey: kHasSeenShortcutTip)
    }

    private func normalizedInteger(
        forKey key: String,
        using normalize: (Int) -> Int
    ) -> Int {
        let rawValue = defaults.integer(forKey: key)
        let normalizedValue = normalize(rawValue)
        if rawValue != normalizedValue {
            defaults.set(normalizedValue, forKey: key)
        }
        return normalizedValue
    }

    private func normalizedDouble(
        forKey key: String,
        using normalize: (Double) -> Double
    ) -> Double {
        let rawValue = defaults.double(forKey: key)
        let normalizedValue = normalize(rawValue)
        if rawValue != normalizedValue {
            defaults.set(normalizedValue, forKey: key)
        }
        return normalizedValue
    }

    func isWeekdayHighlighted(_ column: Int, weekStartWeekday: Int) -> Bool {
        let dow = weekdayForColumn(startDOW: weekStartWeekday, col: column)
        return (highlightedWeekdays & (1 << dow)) != 0
    }
}
