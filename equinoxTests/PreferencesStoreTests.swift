import XCTest
@testable import equinox

@MainActor
final class PreferencesStoreTests: XCTestCase {
    func testShowEventDotsKeyIsLegacyLiteral() {
        XCTAssertEqual(kShowEventDots, "kShowEventDots")
    }

    func testRegisteredDefaultsIncludeEveryPersistedPreferenceKey() {
        let defaults = PreferencesStore.registeredDefaultValues()

        let persistedKeys: [(String, String)] = [
            ("isPanelPinned", kPanelPinned),
            ("showEventDays", kShowEventDays),
            ("weekStartWeekday", kWeekStartDOW),
            ("highlightedWeekdays", kHighlightedDOWs),
            ("showWeeks", kShowWeeks),
            ("showEventDots", kShowEventDots),
            ("showLocation", kShowLocation),
            ("showDaysWithNoEvents", kShowDaysWithNoEventsInAgenda),
            ("menuBarIconType", kMenuBarIconType),
            ("showMonthInIcon", kShowMonthInIcon),
            ("showDayOfWeekInIcon", kShowDayOfWeekInIcon),
            ("isIconHidden", kHideIcon),
            ("showMeetingIndicator", kShowMeetingIndicator),
            ("themePreference", kThemePreference),
            ("sizePreference", kSizePreference),
            ("backgroundStyle", kBackgroundStyle),
            ("calendarRowCount", kCalendarNumRows),
            ("showMonthBoundaries", kShowMonthBoundaries),
            ("agendaHeightRatio", kAgendaHeightRatio),
            ("isPlaudEnabled", kPlaudEnabled),
            ("hasSeenShortcutTip", kHasSeenShortcutTip),
        ]

        for (property, key) in persistedKeys {
            XCTAssertNotNil(defaults[key], "Missing registered default for PreferencesStore.\(property) (\(key))")
        }

        // clockFormat uses nil as default and is intentionally omitted from registerDefaults.
        XCTAssertNil(defaults[kClockFormat])
    }

    func testRegisteredDefaultValuesMatchInitDefaults() {
        let defaults = PreferencesStore.registeredDefaultValues()
        XCTAssertEqual(defaults[kShowEventDots] as? Bool, true)
        XCTAssertEqual(defaults[kThemePreference] as? Int, ThemePreference.system.rawValue)
        XCTAssertEqual(defaults[kMenuBarIconType] as? Int, MenuBarIconStyle.minimal.rawValue)
        XCTAssertEqual(defaults[kBackgroundStyle] as? Int, BackgroundStyle.glass.rawValue)
        XCTAssertEqual(defaults[kSizePreference] as? Int, SizePreference.medium.rawValue)
        XCTAssertEqual(defaults[kAgendaHeightRatio] as? Double, 0.35)
        XCTAssertEqual(defaults[kCalendarNumRows] as? Int, 6)
    }

    func testMenuBarIconStyleClampingRangeMatchesCaseCount() {
        XCTAssertEqual(MenuBarIconStyle.clampedRange.upperBound, MenuBarIconStyle.allCases.count - 1)
    }

    func testInitializerRegistersAndLoadsDefaultsInIsolatedStore() {
        withIsolatedDefaults { defaults in
            let store = PreferencesStore(defaults: defaults)
            let registered = PreferencesStore.registeredDefaultValues()

            XCTAssertEqual(store.isPanelPinned, registered[kPanelPinned] as? Bool)
            XCTAssertEqual(store.showEventDays, registered[kShowEventDays] as? Int)
            XCTAssertEqual(store.weekStartWeekday, registered[kWeekStartDOW] as? Int)
            XCTAssertEqual(store.highlightedWeekdays, registered[kHighlightedDOWs] as? Int)
            XCTAssertEqual(store.themePreference, ThemePreference.system.rawValue)
            XCTAssertEqual(store.sizePreference, SizePreference.medium.rawValue)
            XCTAssertEqual(store.backgroundStyle, BackgroundStyle.glass.rawValue)
        }
    }

    func testPropertyChangesPersistToInjectedDefaults() {
        withIsolatedDefaults { defaults in
            let store = PreferencesStore(defaults: defaults)

            store.showLocation = true
            store.calendarRowCount = 9
            store.clockFormat = "HH:mm"

            XCTAssertTrue(defaults.bool(forKey: kShowLocation))
            XCTAssertEqual(defaults.integer(forKey: kCalendarNumRows), 9)
            XCTAssertEqual(defaults.string(forKey: kClockFormat), "HH:mm")
        }
    }

    func testInitializerNormalizesAndWritesBackConstrainedValues() {
        withIsolatedDefaults { defaults in
            defaults.set(-4, forKey: kWeekStartDOW)
            defaults.set(0x1FF, forKey: kHighlightedDOWs)
            defaults.set(99, forKey: kThemePreference)
            defaults.set(99, forKey: kSizePreference)
            defaults.set(99, forKey: kBackgroundStyle)
            defaults.set(99, forKey: kMenuBarIconType)
            defaults.set(99, forKey: kShowEventDays)
            defaults.set(2, forKey: kCalendarNumRows)
            defaults.set(0.9, forKey: kAgendaHeightRatio)

            let store = PreferencesStore(defaults: defaults)

            let expectedValues: [(String, Int, Int)] = [
                (kWeekStartDOW, store.weekStartWeekday, 0),
                (kHighlightedDOWs, store.highlightedWeekdays, 0x7F),
                (kThemePreference, store.themePreference, ThemePreference.system.rawValue),
                (kSizePreference, store.sizePreference, SizePreference.medium.rawValue),
                (kBackgroundStyle, store.backgroundStyle, BackgroundStyle.glass.rawValue),
                (kMenuBarIconType, store.menuBarIconType, MenuBarIconStyle.clampedRange.upperBound),
                (kShowEventDays, store.showEventDays, 9),
                (kCalendarNumRows, store.calendarRowCount, 6),
            ]
            for (key, actual, expected) in expectedValues {
                XCTAssertEqual(actual, expected, "Unexpected normalized value for \(key)")
                XCTAssertEqual(defaults.integer(forKey: key), expected, "Did not write back \(key)")
            }
            XCTAssertEqual(store.agendaHeightRatio, 0.65)
            XCTAssertEqual(defaults.double(forKey: kAgendaHeightRatio), 0.65)
        }
    }

    func testZeroAndNonFiniteAgendaRatioUseSafeDefault() {
        for invalidValue in [0, Double.nan, Double.infinity] {
            withIsolatedDefaults { defaults in
                defaults.set(invalidValue, forKey: kAgendaHeightRatio)
                let store = PreferencesStore(defaults: defaults)

                XCTAssertEqual(store.agendaHeightRatio, 0.35)
                XCTAssertEqual(defaults.double(forKey: kAgendaHeightRatio), 0.35)
            }
        }
    }

    func testResetUsesInjectedDefaultsAndClearsInjectedCalendarSelection() {
        let standardSelection = CalendarSelectionStorage.loadSelectedIDs()

        withIsolatedDefaults { defaults in
            let store = PreferencesStore(defaults: defaults)
            store.showLocation = true
            store.clockFormat = "HH:mm"
            CalendarSelectionStorage.saveSelectedIDs(["isolated-calendar"], to: defaults)

            store.resetToDefaults()

            XCTAssertFalse(store.showLocation)
            XCTAssertNil(store.clockFormat)
            XCTAssertTrue(CalendarSelectionStorage.loadSelectedIDs(from: defaults).isEmpty)
            XCTAssertEqual(CalendarSelectionStorage.loadSelectedIDs(), standardSelection)
        }
    }

    func testInitializationAndMutationsPostExactNotificationCounts() {
        withIsolatedDefaults { defaults in
            let center = NotificationCenter()
            let counter = NotificationCounter()
            let sizeObserver = center.addObserver(
                forName: kEquinoxSizePreferenceChanged,
                object: nil,
                queue: nil
            ) { _ in counter.incrementSize() }
            let menuObserver = center.addObserver(
                forName: kEquinoxMenuBarAppearanceChanged,
                object: nil,
                queue: nil
            ) { _ in counter.incrementMenu() }
            defer {
                center.removeObserver(sizeObserver)
                center.removeObserver(menuObserver)
            }

            let store = PreferencesStore(defaults: defaults, notificationCenter: center)
            XCTAssertEqual(counter.counts, .init(size: 0, menu: 0))

            store.sizePreference = SizePreference.large.rawValue
            store.showMonthInIcon = true
            XCTAssertEqual(counter.counts, .init(size: 1, menu: 1))

            store.resetToDefaults()
            XCTAssertEqual(counter.counts, .init(size: 2, menu: 2))
        }
    }

    private func withIsolatedDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "PreferencesStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }
}

private final class NotificationCounter: @unchecked Sendable {
    struct Counts: Equatable {
        let size: Int
        let menu: Int
    }

    private let lock = NSLock()
    private var sizeCount = 0
    private var menuCount = 0

    var counts: Counts {
        lock.withLock { Counts(size: sizeCount, menu: menuCount) }
    }

    func incrementSize() {
        lock.withLock { sizeCount += 1 }
    }

    func incrementMenu() {
        lock.withLock { menuCount += 1 }
    }
}
