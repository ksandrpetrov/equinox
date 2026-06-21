import XCTest
@testable import equinox

final class PreferencesStoreTests: XCTestCase {
    func testShowEventDotsKeyIsLegacyLiteral() {
        XCTAssertEqual(kShowEventDots, "kShowEventDots")
    }

    func testRegisteredDefaultsIncludeEveryPersistedPreferenceKey() {
        let defaults = PreferencesStore.registeredDefaultValues()
        XCTAssertNotNil(defaults[kShowEventDots])
        XCTAssertEqual(defaults[kThemePreference] as? Int, ThemePreference.system.rawValue)
        XCTAssertEqual(defaults[kMenuBarIconType] as? Int, MenuBarIconStyle.minimal.rawValue)
        XCTAssertEqual(defaults[kBackgroundStyle] as? Int, BackgroundStyle.glass.rawValue)
        XCTAssertEqual(defaults[kSizePreference] as? Int, SizePreference.medium.rawValue)
    }

    func testMenuBarIconStyleClampingRangeMatchesCaseCount() {
        XCTAssertEqual(MenuBarIconStyle.clampedRange.upperBound, MenuBarIconStyle.allCases.count - 1)
    }
}
