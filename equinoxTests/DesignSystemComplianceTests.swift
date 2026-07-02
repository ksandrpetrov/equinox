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
        let enumerator = FileManager.default.enumerator(
            at: root.appendingPathComponent(uiRoot),
            includingPropertiesForKeys: nil
        )
        var paths: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            if excludingDesign, url.path.contains("/Design/") { continue }
            paths.append(url.path)
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
        return url.deletingLastPathComponent()
    }
}
