import Foundation

actor PlaudService {
    private let liveClient = PlaudLiveClient()
    private let recordingsStore = PlaudRecordingsStore()
    private let cache = PlaudMatchCache()

    private var recordings: [PlaudRecording] = []
    private var catalogFingerprint = ""
    private var lastRefreshAt: Date?
    private var lastError: String?

    private static let staleInterval: TimeInterval = 6 * 60 * 60

    init() {
        if let snapshot = recordingsStore.load() {
            recordings = snapshot.recordings
            catalogFingerprint = snapshot.fingerprint
            lastRefreshAt = snapshot.fetchedAt
        }
    }

    func setupStatus() -> PlaudSetup {
        PlaudConfigurator.buildSetup(
            recordCount: recordings.count,
            lastRefreshAt: lastRefreshAt,
            cacheStats: cache.stats(),
            lastError: lastError
        )
    }

    func refreshIfNeeded(force: Bool = false, isPlaudEnabled: Bool) async -> PlaudSetup {
        guard isPlaudEnabled else {
            return setupStatus()
        }

        let shouldRefresh = force
            || lastRefreshAt == nil
            || Date().timeIntervalSince(lastRefreshAt!) >= Self.staleInterval

        guard shouldRefresh else {
            return setupStatus()
        }

        do {
            try await reloadCatalog()
            if force {
                cache.clearNegatives()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }

        return setupStatus()
    }

    func saveManualLink(for event: DayEvent, url: URL) throws -> PlaudEventMatch {
        guard let eventID = event.eventIdentifier else {
            throw PlaudManualLinkError.missingEventIdentifier
        }
        guard let fileID = PlaudEventMatching.fileID(from: url),
              let webURL = PlaudEventMatching.webURL(for: fileID) else {
            throw PlaudManualLinkError.invalidURL
        }

        let key = PlaudEventMatching.matchKey(eventIdentifier: eventID, startDate: event.startDate)
        let cached = PlaudCachedMatch(
            fileID: fileID,
            webURLString: webURL.absoluteString,
            source: .manual,
            matchedAt: Date()
        )
        cache.storePositive(key: key, match: cached, fingerprint: catalogFingerprint)

        return PlaudEventMatch(
            fileID: fileID,
            webURL: webURL,
            confidence: .high,
            source: .manual
        )
    }

    func allCachedLinks(isPlaudEnabled: Bool) -> [String: PlaudEventMatch] {
        guard isPlaudEnabled else { return [:] }
        return cache.allPositiveMatches().compactMapValues { eventMatch(from: $0) }
    }

    /// Earliest recording timestamp, used to bound the calendar range scanned for matches.
    func recordingsStartDate() -> Date? {
        recordings.map(\.recordedAt).min()
    }

    private func reloadCatalog() async throws {
        let fetched = try await liveClient.fetchRecordings()
        let fingerprint = PlaudRecordingsStore.fingerprint(for: fetched)

        if fingerprint != catalogFingerprint {
            cache.invalidateAutoMatches(keepingManual: true, newFingerprint: fingerprint)
            catalogFingerprint = fingerprint
        }

        recordings = fetched
        let now = Date()
        lastRefreshAt = now
        recordingsStore.save(
            PlaudRecordingsSnapshot(
                recordings: fetched,
                fetchedAt: now,
                fingerprint: fingerprint
            )
        )
    }

    func matchEvent(_ event: DayEvent, isPlaudEnabled: Bool, now: Date = Date()) -> PlaudEventMatch? {
        guard isPlaudEnabled else { return nil }
        guard let eventID = event.eventIdentifier else { return nil }

        let key = PlaudEventMatching.matchKey(eventIdentifier: eventID, startDate: event.startDate)

        if let cached = cache.positiveMatch(for: key), let match = eventMatch(from: cached) {
            return match
        }

        if cache.isNegative(for: key, fingerprint: catalogFingerprint) {
            return nil
        }

        let matchable = PlaudMatchableEvent(
            eventIdentifier: eventID,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate
        )

        guard let match = PlaudEventMatching.match(event: matchable, recordings: recordings, now: now) else {
            cache.storeNegative(key: key, fingerprint: catalogFingerprint)
            return nil
        }

        let cached = PlaudCachedMatch(
            fileID: match.fileID,
            webURLString: match.webURL.absoluteString,
            source: .auto,
            matchedAt: Date()
        )
        cache.storePositive(key: key, match: cached, fingerprint: catalogFingerprint)
        return match
    }

    func refreshMatches(for events: [DayEvent], isPlaudEnabled: Bool) async -> [String: PlaudEventMatch] {
        guard isPlaudEnabled else { return [:] }
        _ = await refreshIfNeeded(isPlaudEnabled: isPlaudEnabled)

        let now = Date()
        var results: [String: PlaudEventMatch] = [:]
        for event in events where event.endDate < now {
            guard let eventID = event.eventIdentifier else { continue }
            let key = PlaudEventMatching.matchKey(eventIdentifier: eventID, startDate: event.startDate)
            if let match = matchEvent(event, isPlaudEnabled: isPlaudEnabled, now: now) {
                results[key] = match
            }
        }
        return results
    }

    private func eventMatch(from cached: PlaudCachedMatch) -> PlaudEventMatch? {
        guard let webURL = cached.webURL ?? PlaudEventMatching.webURL(for: cached.fileID) else { return nil }
        return PlaudEventMatch(
            fileID: cached.fileID,
            webURL: webURL,
            confidence: .high,
            source: cached.source
        )
    }
}

enum PlaudManualLinkError: LocalizedError {
    case missingEventIdentifier
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .missingEventIdentifier:
            return String(localized: "This event has no stable identifier.", comment: "Plaud manual link error")
        case .invalidURL:
            return String(
                localized: "Paste a Plaud URL like https://web.plaud.ai/file/…",
                comment: "Plaud manual link error"
            )
        }
    }
}
