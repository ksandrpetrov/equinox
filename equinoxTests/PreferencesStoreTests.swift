import XCTest
@testable import equinox

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
            ("isMcpEnabled", kMcpEnabled),
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
}
