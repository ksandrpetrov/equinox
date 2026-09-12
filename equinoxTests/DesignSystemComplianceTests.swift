import Foundation
import SwiftUI
import XCTest
@testable import EquinoxKit

final class DesignSystemComplianceTests: XCTestCase {
    private let uiRoot = "equinox/UI"
    private let designPath = "equinox/UI/Design"

    func testFeatureViewsAvoidPrimaryOpacityLiterals() throws {
        let violations = try swiftUIFiles(excludingDesign: true)
            .flatMap { path -> [(String, Int, String)] in
                let lines = try lines(at: path)
                return lines.enumerated().compactMap { index, line in
                    guard line.contains("Color.primary.opacity(") else { return nil }
                    return (path, index + 1, line.trimmingCharacters(in: .whitespaces))
                }
            }

        XCTAssertTrue(
            violations.isEmpty,
            "Color.primary.opacity must live in Design tokens only:\n"
                + violations.map { "\($0.0):\($0.1) \($0.2)" }.joined(separator: "\n")
        )
    }

    func testFeatureViewsAvoidSystemSizeFonts() throws {
        let violations = try swiftUIFiles(excludingDesign: true)
            .flatMap { path -> [(String, Int, String)] in
                let lines = try lines(at: path)
                return lines.enumerated().compactMap { index, line in
                    guard line.contains(".font(.system(size:") else { return nil }
                    return (path, index + 1, line.trimmingCharacters(in: .whitespaces))
                }
            }

        XCTAssertTrue(
            violations.isEmpty,
            "Use EquinoxDesign font helpers or semantic fonts instead of .font(.system(size:)):\n"
                + violations.map { "\($0.0):\($0.1) \($0.2)" }.joined(separator: "\n")
        )
    }

    func testFeatureViewsWrapHoverAnimationWithReduceMotion() throws {
        let violations = try swiftUIFiles(excludingDesign: true)
            .flatMap { path -> [(String, Int, String)] in
                let lines = try lines(at: path)
                return lines.enumerated().compactMap { index, line in
                    guard line.contains(".animation(EquinoxDesign.hoverAnimation"),
                          !line.contains("EquinoxDesign.animation(EquinoxDesign.hoverAnimation")
                    else { return nil }
                    return (path, index + 1, line.trimmingCharacters(in: .whitespaces))
                }
            }

        XCTAssertTrue(
            violations.isEmpty,
            "Use EquinoxDesign.animation(_:reduceMotion:) for hover animations:\n"
                + violations.map { "\($0.0):\($0.1) \($0.2)" }.joined(separator: "\n")
        )
    }

    func testFeatureViewsAvoidSecondaryOpacityLiterals() throws {
        try assertNoOccurrences(
            of: "Color.secondary.opacity(",
            message: "Color.secondary.opacity must be a Design token (see ColorToken.weekdayDimmed)"
        )
    }

    func testFeatureViewsAvoidBareBlackWhiteInk() throws {
        try assertNoMatches(
            regex: #"\.(white|black)\b"#,
            message: "Use design ink tokens (MenuBarDesign.previewInk*/templateInk) instead of .white/.black",
            extraExcludedDirectories: ["/MenuBar/"]
        )
    }

    func testFeatureViewsAvoidMagicOpacityLiterals() throws {
        try assertNoMatches(
            regex: #"\.opacity\(0\.[0-9]+\)"#,
            message: "Move opacity literals into EquinoxDesign.StateOpacity tokens"
        )
    }

    func testNoReferencesToRemovedMenuBarAssets() throws {
        for name in ["meetSolid", "meetOutline", "menubaricon"] {
            try assertNoOccurrences(
                of: name,
                message: "\(name) asset was removed; use MenuBarIconRenderer/MenuBarMeetingGlyph"
            )
        }
    }

    func testSmallAgendaTextMeetsReadableMinimum() {
        let metrics = SizeMetrics.metrics(for: .small)
        XCTAssertGreaterThanOrEqual(metrics.agendaEventMetaFontSize, 10)
        XCTAssertGreaterThanOrEqual(metrics.agendaTimeFontSize, 10)
        XCTAssertGreaterThanOrEqual(metrics.agendaEventTitleFontSize, 11)
        XCTAssertGreaterThanOrEqual(
            EquinoxDesign.minimumReadableFontSize,
            10
        )
    }

    func testLightAccentMeetsAAContrastWithAccentForeground() throws {
        let accent = try assetRGB(named: "AccentColor")
        let foreground = try assetRGB(named: "OnAccentForeground")
        XCTAssertGreaterThanOrEqual(
            contrastRatio(accent, foreground),
            4.5,
            "Light AccentColor must keep at least 4.5:1 contrast with OnAccentForeground"
        )
    }

    func testToolbarTargetsMeetMacOSMinimumAcrossSizes() {
        for size in SizePreference.allCases {
            XCTAssertGreaterThanOrEqual(SizeMetrics.metrics(for: size).toolbarButtonSize, 28)
        }
    }

    func testAgendaRowsMeetToolbarTargetsAcrossSizes() {
        for preference in SizePreference.allCases {
            let metrics = SizeMetrics.metrics(for: preference)
            XCTAssertGreaterThanOrEqual(
                metrics.agendaRowMinHeight,
                metrics.toolbarButtonSize
            )
        }
    }

    func testAgendaActionsRemainSeparateAccessibilityElements() throws {
        let root = try repoRoot()
        let agendaPath = root.appendingPathComponent("equinox/UI/Main/AgendaComponents.swift").path
        let overlayPath = root.appendingPathComponent("equinox/UI/Main/PanelStateOverlay.swift").path
        let agendaSource = try String(contentsOfFile: agendaPath, encoding: .utf8)
        let overlaySource = try String(contentsOfFile: overlayPath, encoding: .utf8)

        XCTAssertFalse(agendaSource.contains(".accessibilityElement(children: .combine)"))
        XCTAssertTrue(overlaySource.contains(".accessibilityElement(children: .contain)"))
    }

    func testSurfaceTokensUseAdaptiveSystemColors() throws {
        let root = try repoRoot()
        let path = root.appendingPathComponent("equinox/UI/Design/DesignTokens.swift").path
        let source = try String(contentsOfFile: path, encoding: .utf8)

        for removedAsset in ["SurfacePrimary", "SurfaceSecondary", "SurfaceWindow", "SurfaceRaised"] {
            XCTAssertFalse(source.contains("Color(\"\(removedAsset)\")"))
        }
    }

    func testCalendarGridPreservesDayCellAccessibilityElements() throws {
        let root = try repoRoot()
        let path = root.appendingPathComponent("equinox/UI/Main/CalendarGridView.swift").path
        let source = try String(contentsOfFile: path, encoding: .utf8)

        XCTAssertTrue(
            source.contains(".accessibilityElement(children: .contain)"),
            "CalendarGridView must keep each DayCellView as a separately labelled accessibility element"
        )
    }

    func testCalendarUsesOneKeyboardFocusTarget() throws {
        let root = try repoRoot()
        let path = root.appendingPathComponent("equinox/UI/Main/DayCellView.swift").path
        let source = try String(contentsOfFile: path, encoding: .utf8)

        XCTAssertTrue(
            source.contains(".focusable(false)"),
            "Individual day buttons must not compete with the arrow-key calendar focus target"
        )
    }

    func testRussianAppearanceAndErrorStringsAreLocalized() throws {
        let bundle = Bundle.equinox
        let locale = Locale(identifier: "ru")
        let localized: (String.LocalizationValue) -> String = {
            String(localized: $0, bundle: bundle, locale: locale)
        }

        XCTAssertEqual(localized("Calendar rows"), "Строки календаря")
        XCTAssertEqual(localized("Dismiss"), "Закрыть")
        XCTAssertEqual(localized("Go to Today"), "Перейти к сегодняшнему дню")
        XCTAssertEqual(localized("Global Shortcut"), "Глобальная горячая клавиша")
        XCTAssertEqual(localized("Panel Shortcuts"), "Горячие клавиши панели")
        XCTAssertEqual(localized("Show event details."), "Открыть сведения о событии.")
        XCTAssertEqual(localized("Delete this occurrence?"), "Удалить только это событие?")
        XCTAssertEqual(
            localized("Camera icon when a meeting is starting soon"),
            "Значок камеры, когда встреча скоро начнётся"
        )
        XCTAssertEqual(localized("Could not delete event"), "Не удалось удалить событие.")
        XCTAssertEqual(
            localized("End date must be after start date."),
            "Дата окончания должна быть позже даты начала."
        )
        XCTAssertEqual(
            localized("Enable Full Access for Equinox in System Settings."),
            "Включите полный доступ для Equinox в системных настройках."
        )

        func formattedEventCount(_ count: Int64, format: String, locale: Locale) -> String {
            String(format: format, locale: locale, arguments: [count])
        }

        let eventCountFormat = localized("%lld events")
        let russianLocale = Locale(identifier: "ru")
        XCTAssertEqual(formattedEventCount(1, format: eventCountFormat, locale: russianLocale), "1 событие")
        XCTAssertEqual(formattedEventCount(2, format: eventCountFormat, locale: russianLocale), "2 события")
        XCTAssertEqual(formattedEventCount(5, format: eventCountFormat, locale: russianLocale), "5 событий")
        XCTAssertEqual(formattedEventCount(21, format: eventCountFormat, locale: russianLocale), "21 событие")

        let englishLocalizationPath = try XCTUnwrap(
            bundle.path(forResource: "en", ofType: "lproj")
        )
        let englishBundle = try XCTUnwrap(Bundle(path: englishLocalizationPath))
        let englishEventCountFormat = englishBundle.localizedString(
            forKey: "%lld events",
            value: nil,
            table: nil
        )
        let englishLocale = Locale(identifier: "en")
        XCTAssertEqual(formattedEventCount(1, format: englishEventCountFormat, locale: englishLocale), "1 event")
        XCTAssertEqual(formattedEventCount(2, format: englishEventCountFormat, locale: englishLocale), "2 events")
        XCTAssertEqual(formattedEventCount(5, format: englishEventCountFormat, locale: englishLocale), "5 events")
        XCTAssertEqual(formattedEventCount(21, format: englishEventCountFormat, locale: englishLocale), "21 events")
    }

    func testEveryStaticLocalizedLiteralHasRussianTranslation() throws {
        let root = try repoRoot()
        let localizedLiteral = try NSRegularExpression(
            pattern: "String\\s*\\(\\s*localized:\\s*\"([^\"]+)\""
        )
        let translationEntry = try NSRegularExpression(
            pattern: "(?m)^\\s*\"([^\"]+)\"\\s*="
        )

        var sourceKeys = Set<String>()
        for path in try swiftSourceFiles() {
            let source = try String(contentsOfFile: path, encoding: .utf8)
            let range = NSRange(source.startIndex..<source.endIndex, in: source)
            for match in localizedLiteral.matches(in: source, range: range) {
                guard let keyRange = Range(match.range(at: 1), in: source) else { continue }
                sourceKeys.insert(String(source[keyRange]))
            }
        }

        let stringsPath = root.appendingPathComponent("equinox/ru.lproj/Localizable.strings").path
        let strings = try String(contentsOfFile: stringsPath, encoding: .utf8)
        let stringsRange = NSRange(strings.startIndex..<strings.endIndex, in: strings)
        let stringKeys = Set(translationEntry.matches(in: strings, range: stringsRange).compactMap { match in
            Range(match.range(at: 1), in: strings).map { String(strings[$0]) }
        })
        let stringsDictPath = root.appendingPathComponent("equinox/ru.lproj/Localizable.stringsdict").path
        let stringsDictData = try Data(contentsOf: URL(fileURLWithPath: stringsDictPath))
        let pluralEntries = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: stringsDictData, format: nil) as? [String: Any]
        )
        let translatedKeys = stringKeys.union(pluralEntries.keys)
        let missingKeys = sourceKeys.subtracting(translatedKeys).sorted()

        XCTAssertTrue(
            missingKeys.isEmpty,
            "Static String(localized:) literals missing from ru.lproj/Localizable.strings:\n"
                + missingKeys.joined(separator: "\n")
        )
    }


    private func assertNoOccurrences(
        of substring: String,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let violations = try swiftUIFiles(excludingDesign: true)
            .flatMap { path -> [(String, Int, String)] in
                try lines(at: path).enumerated().compactMap { index, text in
                    guard text.contains(substring) else { return nil }
                    return (path, index + 1, text.trimmingCharacters(in: .whitespaces))
                }
            }
        XCTAssertTrue(
            violations.isEmpty,
            "\(message):\n" + violations.map { "\($0.0):\($0.1) \($0.2)" }.joined(separator: "\n"),
            file: file,
            line: line
        )
    }

    private func assertNoMatches(
        regex pattern: String,
        message: String,
        extraExcludedDirectories: [String] = [],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let expression = try NSRegularExpression(pattern: pattern)
        let violations = try swiftUIFiles(excludingDesign: true)
            .filter { path in !extraExcludedDirectories.contains { path.contains($0) } }
            .flatMap { path -> [(String, Int, String)] in
                try lines(at: path).enumerated().compactMap { index, text in
                    let range = NSRange(text.startIndex..<text.endIndex, in: text)
                    guard expression.firstMatch(in: text, range: range) != nil else { return nil }
                    return (path, index + 1, text.trimmingCharacters(in: .whitespaces))
                }
            }
        XCTAssertTrue(
            violations.isEmpty,
            "\(message):\n" + violations.map { "\($0.0):\($0.1) \($0.2)" }.joined(separator: "\n"),
            file: file,
            line: line
        )
    }

    private func swiftUIFiles(excludingDesign: Bool) throws -> [String] {
        let root = try repoRoot()
        guard let enumerator = FileManager.default.enumerator(
            at: root.appendingPathComponent(uiRoot),
            includingPropertiesForKeys: nil
        ) else {
            throw NSError(domain: "DesignSystemComplianceTests", code: 2)
        }
        var paths: [String] = []
        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            if excludingDesign, url.path.contains("/Design/") { continue }
            paths.append(url.path)
        }
        guard !paths.isEmpty else {
            throw NSError(domain: "DesignSystemComplianceTests", code: 3)
        }
        return paths.sorted()
    }

    private func swiftSourceFiles() throws -> [String] {
        let sourceRoot = try repoRoot().appendingPathComponent("equinox")
        guard let enumerator = FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        ) else {
            throw NSError(domain: "DesignSystemComplianceTests", code: 4)
        }
        var paths: [String] = []
        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            paths.append(url.path)
        }
        return paths.sorted()
    }

    private func lines(at path: String) throws -> [String] {
        try String(contentsOfFile: path, encoding: .utf8).components(separatedBy: .newlines)
    }

    private struct RGB {
        let red: Double
        let green: Double
        let blue: Double
    }

    private func assetRGB(named name: String) throws -> RGB {
        let path = try repoRoot()
            .appendingPathComponent("equinox/Colors.xcassets/\(name).colorset/Contents.json")
        let data = try Data(contentsOf: path)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let colors = root["colors"] as? [[String: Any]],
              let lightEntry = colors.first(where: { $0["appearances"] == nil }),
              let color = lightEntry["color"] as? [String: Any],
              let components = color["components"] as? [String: String],
              let red = components["red"].flatMap(Double.init),
              let green = components["green"].flatMap(Double.init),
              let blue = components["blue"].flatMap(Double.init) else {
            throw NSError(domain: "DesignSystemComplianceTests", code: 5)
        }
        return RGB(red: red, green: green, blue: blue)
    }

    private func contrastRatio(_ lhs: RGB, _ rhs: RGB) -> Double {
        let lhsLuminance = relativeLuminance(lhs)
        let rhsLuminance = relativeLuminance(rhs)
        return (max(lhsLuminance, rhsLuminance) + 0.05)
            / (min(lhsLuminance, rhsLuminance) + 0.05)
    }

    private func relativeLuminance(_ color: RGB) -> Double {
        0.2126 * linearized(color.red)
            + 0.7152 * linearized(color.green)
            + 0.0722 * linearized(color.blue)
    }

    private func linearized(_ component: Double) -> Double {
        if component <= 0.04045 {
            return component / 12.92
        }
        return pow((component + 0.055) / 1.055, 2.4)
    }

    private func repoRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("equinox.xcodeproj/project.pbxproj").path) && url.path != "/" {
            url.deleteLastPathComponent()
        }
        guard url.path != "/" else {
            throw NSError(domain: "DesignSystemComplianceTests", code: 1)
        }
        return url
    }
}
