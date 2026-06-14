import Foundation

struct PlaudCatalogSnapshot: Sendable {
    let recordings: [PlaudRecording]
    let indexFingerprint: String
    let recordCount: Int
    let indexModifiedAt: Date?
}

enum PlaudCatalogError: LocalizedError {
    case indexNotFound
    case invalidIndexFormat
    case bookmarkResolutionFailed

    var errorDescription: String? {
        switch self {
        case .indexNotFound:
            return String(localized: "Plaud sync index file not found.", comment: "Plaud catalog error")
        case .invalidIndexFormat:
            return String(localized: "Plaud sync index has an unexpected format.", comment: "Plaud catalog error")
        case .bookmarkResolutionFailed:
            return String(localized: "Could not access the Plaud sync index file.", comment: "Plaud catalog error")
        }
    }
}

actor PlaudCatalog {
    private var cachedSnapshot: PlaudCatalogSnapshot?

    func loadSnapshot(
        indexPath: String?,
        bookmarkData: Data?
    ) throws -> PlaudCatalogSnapshot {
        let url = try resolveIndexURL(indexPath: indexPath, bookmarkData: bookmarkData)
        let snapshot = try Self.parseIndex(at: url)
        cachedSnapshot = snapshot
        return snapshot
    }

    func currentSnapshot() -> PlaudCatalogSnapshot? {
        cachedSnapshot
    }

    static func fingerprint(for url: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date,
              let size = attributes[.size] as? NSNumber else {
            return "missing"
        }
        return "\(Int(modified.timeIntervalSince1970))|\(size.intValue)"
    }

    private func resolveIndexURL(indexPath: String?, bookmarkData: Data?) throws -> URL {
        if let bookmarkData,
           let url = Self.resolveBookmark(bookmarkData) {
            return url
        }
        if let indexPath, !indexPath.isEmpty {
            let url = URL(fileURLWithPath: indexPath)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw PlaudCatalogError.indexNotFound
            }
            return url
        }
        throw PlaudCatalogError.indexNotFound
    }

    static func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        return url
    }

    static func makeBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    static func parseIndex(at url: URL) throws -> PlaudCatalogSnapshot {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url) else {
            throw PlaudCatalogError.indexNotFound
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let records = root["records"] as? [String: [String: Any]] else {
            throw PlaudCatalogError.invalidIndexFormat
        }

        let fingerprint = fingerprint(for: url)
        let modifiedAt = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date

        var recordings: [PlaudRecording] = []
        recordings.reserveCapacity(records.count)

        for (_, record) in records {
            guard let recording = parseRecord(record) else { continue }
            recordings.append(recording)
        }

        return PlaudCatalogSnapshot(
            recordings: recordings,
            indexFingerprint: fingerprint,
            recordCount: recordings.count,
            indexModifiedAt: modifiedAt
        )
    }

    static func parseRecord(_ record: [String: Any]) -> PlaudRecording? {
        guard let fileID = fileID(from: record) else { return nil }
        let title = (record["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? fileID
        guard let recordedAt = parseCreatedAt(record["createdAt"]) else { return nil }

        let folderSegment = (record["folderSegment"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let summaryHash = (record["summaryHash"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let summaryPath = (record["summaryPath"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasSummary = !summaryHash.isEmpty || !summaryPath.isEmpty

        return PlaudRecording(
            fileID: fileID,
            title: title,
            recordedAt: recordedAt,
            folderSegment: folderSegment?.isEmpty == true ? nil : folderSegment,
            hasSummary: hasSummary
        )
    }

    static func fileID(from record: [String: Any]) -> String? {
        let stableID = (record["stableId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if stableID.lowercased().hasPrefix("plaud:") {
            let hex = String(stableID.dropFirst("plaud:".count))
                .lowercased()
                .replacingOccurrences(of: "-", with: "")
            if hex.count == 32, hex.allSatisfy(\.isHexDigit) { return hex }
        }
        return nil
    }

    static func parseCreatedAt(_ value: Any?) -> Date? {
        if let date = parseEpoch(value) { return date }

        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }

        if let date = parseEpoch(text) { return date }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }

        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: text) { return date }

        // The Plaud sync-index stores naive timestamps without a timezone, but Plaud's
        // recording createdAt is effectively UTC (verified against real events, e.g. the
        // 2026-06-11T12:00:26 recording lands in the 12:00-13:00 UTC meeting slot). Force a
        // fixed UTC frame so parsing is device-independent and aligns with UTC calendar dates.
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    /// Parses a numeric epoch (seconds or milliseconds) delivered either as a JSON number
    /// or a purely numeric string. Used by the live Plaud API path, which may return epochs.
    static func parseEpoch(_ value: Any?) -> Date? {
        let raw: Double?
        if let number = value as? NSNumber, !(value is String) {
            raw = number.doubleValue
        } else if let text = value as? String,
                  !text.isEmpty,
                  text.allSatisfy({ $0.isNumber || $0 == "." }),
                  let number = Double(text) {
            raw = number
        } else {
            raw = nil
        }
        // Reject small values (e.g. a bare "2026") that are not plausible epochs.
        guard let value = raw, value >= 100_000_000 else { return nil }
        let seconds = value > 1_000_000_000_000 ? value / 1000 : value
        return Date(timeIntervalSince1970: seconds)
    }
}
