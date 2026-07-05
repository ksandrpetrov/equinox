import XCTest
@testable import equinox

final class BridgeCommandSyncTests: XCTestCase {
    func testGeneratedBridgeCommandsMatchSchemaSource() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let schemaURL = repoRoot
            .appendingPathComponent("bridge/schema/bridge-protocol.schema.json")
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: schemaURL)) as? [String: Any]
        let schemaCommands = schema?["commands"] as? [String]
        let schemaMutableFields = schema?["updateMutableFields"] as? [String]
        XCTAssertEqual(Set(BridgeCommandNames.all), Set(schemaCommands ?? []))
        XCTAssertEqual(BridgeCommandNames.all.count, schemaCommands?.count)
        XCTAssertEqual(Set(BridgeCommandNames.updateMutableFields), Set(schemaMutableFields ?? []))
    }

    func testEventKitBridgeDispatchCoversAllSchemaCommands() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let bridgeSourceURL = repoRoot.appendingPathComponent("bridge/EventKitBridge.swift")
        let constantsURL = repoRoot.appendingPathComponent("equinox/Core/Generated/BridgeCommandNames.generated.swift")
        let bridgeSource = try String(contentsOf: bridgeSourceURL, encoding: .utf8)
        let constantsSource = try String(contentsOf: constantsURL, encoding: .utf8)
        let handledCommands = Set(
            bridgeSource
                .components(separatedBy: .newlines)
                .compactMap { line -> String? in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.hasPrefix("case BridgeCommandNames.") else { return nil }
                    let constantName = trimmed
                        .dropFirst("case BridgeCommandNames.".count)
                        .split(separator: ":")
                        .first
                        .map(String.init) ?? ""
                    return bridgeCommandConstantValue(named: constantName, in: constantsSource)
                }
        )
        XCTAssertEqual(handledCommands, Set(BridgeCommandNames.all))
    }

    func testBridgeUpdateValidationCoversAllMutableFields() {
        for field in BridgeCommandNames.updateMutableFields {
            let hasField = BridgeCommandValidation.bridgeUpdateHasMutableField(
                title: field == "title" ? "x" : nil,
                startDate: field == "startDate" ? "2026-01-01T10:00:00.000Z" : nil,
                endDate: field == "endDate" ? "2026-01-01T11:00:00.000Z" : nil,
                allDay: field == "allDay" ? true : nil,
                location: field == "location" ? "x" : nil,
                notes: field == "notes" ? "x" : nil,
                url: field == "url" ? "https://example.com" : nil,
                calendarId: field == "calendarId" ? "cal-1" : nil
            )
            XCTAssertTrue(hasField, "bridgeUpdateHasMutableField should accept \(field)")
        }
    }

    private func bridgeCommandConstantValue(named constantName: String, in source: String) -> String? {
        let pattern = "static let \(constantName) = \""
        guard let line = source.components(separatedBy: .newlines).first(where: { $0.contains(pattern) }) else {
            return nil
        }
        guard let start = line.range(of: pattern)?.upperBound,
              let end = line[start...].firstIndex(of: "\"") else {
            return nil
        }
        return String(line[start..<end])
    }
}
