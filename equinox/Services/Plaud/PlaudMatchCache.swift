import Foundation

struct PlaudCachedMatch: Codable, Sendable, Equatable {
    let fileID: String
    let webURLString: String
    let source: PlaudMatchSource
    let matchedAt: Date

    var webURL: URL? { URL(string: webURLString) }
}

private struct PlaudMatchCacheFile: Codable {
    let v: Int
    var matches: [String: PlaudCachedMatch]
}

final class PlaudMatchCache: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
    private var data: PlaudMatchCacheFile

    init(fileURL: URL? = nil) {
        let resolved = fileURL ?? Self.defaultFileURL()
        self.fileURL = resolved
        data = Self.load(from: resolved) ?? PlaudMatchCacheFile(v: 1, matches: [:])
    }

    func positiveMatch(for key: String) -> PlaudCachedMatch? {
        lock.withLock { data.matches[key] }
    }

    func storePositive(key: String, match: PlaudCachedMatch) {
        lock.withLock {
            data.matches[key] = match
            persistLocked()
        }
    }

    /// Drops a stale auto-match so the event can be matched again; manual links are never touched.
    func clearAutoMatch(key: String) {
        lock.withLock {
            guard let existing = data.matches[key], existing.source != .manual else { return }
            data.matches.removeValue(forKey: key)
            persistLocked()
        }
    }

    /// Drops every auto-match after the Plaud catalog changed, keeping manual links.
    func invalidateAutoMatches() {
        lock.withLock {
            let kept = data.matches.filter { $0.value.source == .manual }
            guard kept.count != data.matches.count else { return }
            data.matches = kept
            persistLocked()
        }
    }

    func stats() -> (positive: Int, manual: Int) {
        lock.withLock {
            let manual = data.matches.values.filter { $0.source == .manual }.count
            return (data.matches.count, manual)
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
