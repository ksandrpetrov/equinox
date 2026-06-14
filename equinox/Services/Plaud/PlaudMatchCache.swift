import Foundation

struct PlaudCachedMatch: Codable, Sendable, Equatable {
    let fileID: String
    let webURLString: String
    let source: PlaudMatchSource
    let matchedAt: Date

    var webURL: URL? { URL(string: webURLString) }
}

struct PlaudCachedNegative: Codable, Sendable, Equatable {
    let checkedAt: Date
    let indexFingerprint: String
}

private struct PlaudMatchCacheFile: Codable {
    let v: Int
    var indexFingerprint: String
    var matches: [String: PlaudCachedMatch]
    var negatives: [String: PlaudCachedNegative]
}

final class PlaudMatchCache: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
    private var data: PlaudMatchCacheFile

    init(fileURL: URL? = nil) {
        let resolved = fileURL ?? Self.defaultFileURL()
        self.fileURL = resolved
        if let loaded = Self.load(from: resolved) {
            data = loaded
        } else {
            data = PlaudMatchCacheFile(v: 1, indexFingerprint: "", matches: [:], negatives: [:])
        }
    }

    func indexFingerprint() -> String {
        lock.withLock { data.indexFingerprint }
    }

    func positiveMatch(for key: String) -> PlaudCachedMatch? {
        lock.withLock { data.matches[key] }
    }

    func isNegative(for key: String, fingerprint: String) -> Bool {
        lock.withLock {
            guard let negative = data.negatives[key] else { return false }
            return negative.indexFingerprint == fingerprint
        }
    }

    func storePositive(
        key: String,
        match: PlaudCachedMatch,
        fingerprint: String
    ) {
        lock.withLock {
            data.matches[key] = match
            data.negatives.removeValue(forKey: key)
            data.indexFingerprint = fingerprint
            persistLocked()
        }
    }

    func storeNegative(key: String, fingerprint: String) {
        lock.withLock {
            data.negatives[key] = PlaudCachedNegative(checkedAt: Date(), indexFingerprint: fingerprint)
            if data.matches[key]?.source != .manual {
                data.matches.removeValue(forKey: key)
            }
            data.indexFingerprint = fingerprint
            persistLocked()
        }
    }

    func invalidateAutoMatches(keepingManual: Bool, newFingerprint: String) {
        lock.withLock {
            if keepingManual {
                data.matches = data.matches.filter { $0.value.source == .manual }
            } else {
                data.matches = [:]
            }
            data.negatives = [:]
            data.indexFingerprint = newFingerprint
            persistLocked()
        }
    }

    /// Clears cached "no match" decisions so events can be matched again after reconnect or manual refresh.
    func clearNegatives() {
        lock.withLock {
            guard !data.negatives.isEmpty else { return }
            data.negatives = [:]
            persistLocked()
        }
    }

    func stats() -> (positive: Int, negative: Int, manual: Int) {
        lock.withLock {
            let manual = data.matches.values.filter { $0.source == .manual }.count
            return (data.matches.count, data.negatives.count, manual)
        }
    }

    func allPositiveMatches() -> [String: PlaudCachedMatch] {
        lock.withLock { data.matches }
    }

    private func persistLocked() {
        Self.writeAtomic(data, to: fileURL)
    }

    private static func defaultFileURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "equinox"
        let directory = support.appendingPathComponent(bundleID, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("plaud-match-cache.json")
    }

    private static func load(from url: URL) -> PlaudMatchCacheFile? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PlaudMatchCacheFile.self, from: raw)
    }

    private static func writeAtomic(_ value: PlaudMatchCacheFile, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let temp = url.deletingLastPathComponent()
            .appendingPathComponent(".plaud-match-cache.\(ProcessInfo.processInfo.processIdentifier).tmp")
        do {
            try data.write(to: temp, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(at: temp, to: url)
        } catch {
            try? FileManager.default.removeItem(at: temp)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
