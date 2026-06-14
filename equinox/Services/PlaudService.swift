import Foundation

actor PlaudService {
    private let catalog = PlaudCatalog()
    private let liveClient = PlaudLiveClient()
    private let cache = PlaudMatchCache()

    private var recordings: [PlaudRecording] = []
    private var indexFingerprint = ""
    private var lastSnapshot: PlaudCatalogSnapshot?
    private var lastRefreshAt: Date?
    private var lastError: String?

    private static let staleInterval: TimeInterval = 6 * 60 * 60

    func setupStatus(snapshot: PlaudCatalogSnapshot? = nil) -> PlaudSetup {
        let stats = cache.stats()
        return PlaudConfigurator.buildSetup(
            snapshot: snapshot ?? lastSnapshot,
            cacheStats: stats,
            lastError: lastError
        )
    }

    func refreshIfNeeded(force: Bool = false) async -> PlaudSetup {
        guard PreferencesStore.shared.isPlaudEnabled else {
            return setupStatus()
        }

        let shouldRefresh = force
            || lastRefreshAt == nil
            || Date().timeIntervalSince(lastRefreshAt!) >= Self.staleInterval

        guard shouldRefresh else {
            return setupStatus()
        }

        do {
            try await reloadCatalog(allowLive: true)
            lastRefreshAt = Date()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }

        return setupStatus(snapshot: lastSnapshot)
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
            hasSummary: false,
            matchedAt: Date()
        )
        cache.storePositive(key: key, match: cached, fingerprint: indexFingerprint)

        return PlaudEventMatch(
            fileID: fileID,
            webURL: webURL,
            confidence: .high,
            hasSummary: false,
            source: .manual
        )
    }

    func allCachedLinks() -> [String: PlaudEventMatch] {
        cache.allPositiveMatches().compactMapValues { eventMatch(from: $0) }
    }

    private func reloadCatalog(allowLive: Bool) async throws {
        let prefs = PreferencesStore.shared
        let snapshot = try await catalog.loadSnapshot(
            indexPath: prefs.plaudSyncIndexPath,
            bookmarkData: prefs.plaudSyncIndexBookmark
        )

        if snapshot.indexFingerprint != indexFingerprint {
            cache.invalidateAutoMatches(keepingManual: true, newFingerprint: snapshot.indexFingerprint)
            indexFingerprint = snapshot.indexFingerprint
        }

        recordings = snapshot.recordings
        lastSnapshot = snapshot

        if allowLive, shouldTryLiveRefresh(snapshot: snapshot) {
            do {
                let live = try await liveClient.fetchRecordings(
                    exporterDataPath: prefs.plaudExporterDataPath
                )
                recordings = mergeRecordings(index: snapshot.recordings, live: live)
            } catch {
                // Index-only mode is acceptable when live refresh fails.
                lastError = error.localizedDescription
            }
        }
    }

    private func shouldTryLiveRefresh(snapshot: PlaudCatalogSnapshot) -> Bool {
        guard let modified = snapshot.indexModifiedAt else { return true }
        return Date().timeIntervalSince(modified) > Self.staleInterval
    }

    private func mergeRecordings(index: [PlaudRecording], live: [PlaudRecording]) -> [PlaudRecording] {
        var byID = Dictionary(uniqueKeysWithValues: index.map { ($0.fileID, $0) })
        for recording in live {
            byID[recording.fileID] = recording
        }
        return Array(byID.values)
    }

    func matchEvent(_ event: DayEvent, now: Date = Date()) -> PlaudEventMatch? {
        guard PreferencesStore.shared.isPlaudEnabled else { return nil }
        guard let eventID = event.eventIdentifier else { return nil }

        let key = PlaudEventMatching.matchKey(eventIdentifier: eventID, startDate: event.startDate)

        if let cached = cache.positiveMatch(for: key), let match = eventMatch(from: cached) {
            return match
        }

        if cache.isNegative(for: key, fingerprint: indexFingerprint) {
            return nil
        }

        let matchable = PlaudMatchableEvent(
            eventIdentifier: eventID,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate
        )

        guard let match = PlaudEventMatching.match(event: matchable, recordings: recordings, now: now) else {
            cache.storeNegative(key: key, fingerprint: indexFingerprint)
            return nil
        }

        let cached = PlaudCachedMatch(
            fileID: match.fileID,
            webURLString: match.webURL.absoluteString,
            source: .auto,
            hasSummary: match.hasSummary,
            matchedAt: Date()
        )
        cache.storePositive(key: key, match: cached, fingerprint: indexFingerprint)
        return match
    }

    func refreshMatches(for events: [DayEvent]) async -> [String: PlaudEventMatch] {
        guard PreferencesStore.shared.isPlaudEnabled else { return [:] }
        _ = await refreshIfNeeded()

        let now = Date()
        var results: [String: PlaudEventMatch] = [:]
        for event in events where event.endDate < now {
            guard let eventID = event.eventIdentifier else { continue }
            let key = PlaudEventMatching.matchKey(eventIdentifier: eventID, startDate: event.startDate)
            if let match = matchEvent(event, now: now) {
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
            hasSummary: cached.hasSummary,
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
