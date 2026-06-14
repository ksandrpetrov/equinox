import Foundation

struct PlaudRecordingsSnapshot: Codable, Sendable, Equatable {
    let recordings: [PlaudRecording]
    let fetchedAt: Date
    let fingerprint: String

    var recordCount: Int { recordings.count }
}

final class PlaudRecordingsStore: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
    }

    func load() -> PlaudRecordingsSnapshot? {
        lock.withLock {
            Self.load(from: fileURL)
        }
    }

    func save(_ snapshot: PlaudRecordingsSnapshot) {
        lock.withLock {
            Self.writeAtomic(snapshot, to: fileURL)
        }
    }

    static func fingerprint(for recordings: [PlaudRecording]) -> String {
        let count = recordings.count
        let maxRecordedAt = recordings.map(\.recordedAt.timeIntervalSince1970).max() ?? 0
        let sortedIDs = recordings.map(\.fileID).sorted().joined(separator: ",")
        var hasher = Hasher()
        hasher.combine(sortedIDs)
        return "\(count)|\(Int(maxRecordedAt))|\(hasher.finalize())"
    }

    private static func defaultFileURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "equinox"
        let directory = support.appendingPathComponent(bundleID, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("plaud-recordings.json")
    }

    private static func load(from url: URL) -> PlaudRecordingsSnapshot? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PlaudRecordingsSnapshot.self, from: raw)
    }

    private static func writeAtomic(_ value: PlaudRecordingsSnapshot, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let temp = url.deletingLastPathComponent()
            .appendingPathComponent(".plaud-recordings.\(ProcessInfo.processInfo.processIdentifier).tmp")
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
