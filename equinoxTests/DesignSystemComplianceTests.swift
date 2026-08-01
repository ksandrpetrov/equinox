import SwiftUI
import XCTest
@testable import equinox

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
            message: "Move opacity literals into EquinoxDesign.StateOpacity/ShadowToken tokens"
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

    func testDesignTokensExposeMenuBarAndShadowTokens() {
        XCTAssertEqual(MenuBarDesign.barHeight, 16)
        XCTAssertEqual(EquinoxDesign.ShadowToken.panelGlassOpacity, 0.12)
        XCTAssertEqual(EquinoxDesign.EventStripe.width, 3)
        XCTAssertEqual(EquinoxDesign.onAccentForeground, Color.white)
    }

    func testDesignTokensExposeNewComplianceTokens() {
        XCTAssertEqual(EquinoxDesign.ControlWidth.calendarColorDot, 10)
        XCTAssertEqual(EquinoxDesign.ControlWidth.joinIcon, 36)
        XCTAssertEqual(EquinoxDesign.StateOpacity.weekdayDimmed, 0.7)
        XCTAssertEqual(EquinoxDesign.StateOpacity.warningBannerTint, 0.08)
        XCTAssertEqual(EquinoxDesign.StateOpacity.chipForegroundSubtle, 0.85)
    }

    func testToolbarTargetsMeetMacOSMinimumAcrossSizes() {
        XCTAssertEqual(SizeMetrics.metrics(for: .small).toolbarButtonSize, 28)
        XCTAssertEqual(SizeMetrics.metrics(for: .medium).toolbarButtonSize, 30)
        XCTAssertEqual(SizeMetrics.metrics(for: .large).toolbarButtonSize, 32)
    }

    func testGlassEffectIsLimitedToOuterPanelChrome() throws {
        let files = try swiftUIFiles(excludingDesign: false)
        let occurrences = try files.flatMap { path -> [(String, Int)] in
            try lines(at: path).enumerated().compactMap { index, line in
                line.contains(".glassEffect(") ? (path, index + 1) : nil
            }
        }

        XCTAssertEqual(occurrences.count, 1, "Only the outer panel may use glassEffect: \(occurrences)")
        XCTAssertTrue(
            occurrences.first?.0.hasSuffix("/UI/Design/PanelComponents.swift") == true,
            "glassEffect must be owned by PanelComponents"
        )
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

    func testRussianAppearanceAndErrorStringsAreLocalized() {
        let locale = Locale(identifier: "ru")
        let localized: (String.LocalizationValue) -> String = {
            String(localized: $0, bundle: .main, locale: locale)
        }

        XCTAssertEqual(localized("Calendar rows"), "Строки календаря")
        XCTAssertEqual(localized("Dismiss"), "Закрыть")
        XCTAssertEqual(localized("Show event details."), "Показать детали события.")
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
            localized("Open settings from the Equinox menu bar."),
            "Откройте настройки из строки меню Equinox."
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

    private func lines(at path: String) throws -> [String] {
        try String(contentsOfFile: path, encoding: .utf8).components(separatedBy: .newlines)
    }

    private func repoRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while url.lastPathComponent != "equinox" && url.path != "/" {
            url.deleteLastPathComponent()
        }
        guard url.lastPathComponent == "equinox" else {
            throw NSError(domain: "DesignSystemComplianceTests", code: 1)
        }
        return url
    }
}
