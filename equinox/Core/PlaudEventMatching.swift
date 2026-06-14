import Foundation

struct PlaudRecording: Sendable, Equatable, Codable {
    let fileID: String
    let title: String
    let recordedAt: Date
}

enum PlaudMatchConfidence: Sendable, Equatable {
    case high
}

enum PlaudMatchSource: String, Codable, Sendable {
    case auto
    case manual
}

struct PlaudEventMatch: Sendable, Equatable {
    let fileID: String
    let webURL: URL
    let confidence: PlaudMatchConfidence
    let source: PlaudMatchSource
}

struct PlaudMatchableEvent: Sendable, Equatable {
    let eventIdentifier: String
    let title: String
    let startDate: Date
    let endDate: Date
}

enum PlaudEventMatching {
    static let timeWindowBefore: TimeInterval = 45 * 60
    static let timeWindowAfter: TimeInterval = 45 * 60
    static let scoreMarginForHighConfidence = 0.25
    static let minimumTokenLength = 3

    static let webBaseURL = "https://web.plaud.ai/file/"

    static func matchKey(eventIdentifier: String, startDate: Date) -> String {
        "\(eventIdentifier)|\(startDate.timeIntervalSince1970)"
    }

    static func webURL(for fileID: String) -> URL? {
        let normalized = fileID.lowercased().replacingOccurrences(of: "-", with: "")
        guard normalized.count == 32, normalized.allSatisfy(\.isHexDigit) else { return nil }
        return URL(string: webBaseURL + normalized)
    }

    static func fileID(from url: URL) -> String? {
        // Plaud links look like https://web.plaud.ai/file/<id>[/][?query]; the id is the
        // last path component, so ignore any /file/ prefix, trailing slash, or query.
        let candidate = url.lastPathComponent.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !candidate.isEmpty else { return nil }
        let normalized = candidate.lowercased().replacingOccurrences(of: "-", with: "")
        guard normalized.count == 32, normalized.allSatisfy(\.isHexDigit) else { return nil }
        return normalized
    }

    static func match(
        event: PlaudMatchableEvent,
        recordings: [PlaudRecording],
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> PlaudEventMatch? {
        guard event.endDate < now else { return nil }

        let windowStart = event.startDate.addingTimeInterval(-timeWindowBefore)
        let windowEnd = event.endDate.addingTimeInterval(timeWindowAfter)

        let candidates = recordings.compactMap { recording -> ScoredCandidate? in
            let recordedAt = recording.recordedAt
            guard calendar.isDate(recordedAt, inSameDayAs: event.startDate) else { return nil }
            guard recordedAt >= windowStart, recordedAt <= windowEnd else { return nil }
            let timeScore = timeProximityScore(
                recordedAt: recordedAt,
                eventStart: event.startDate,
                eventEnd: event.endDate
            )
            let titleScore = titleTokenScore(eventTitle: event.title, recordingTitle: recording.title)
            let combined = timeScore * 0.7 + titleScore * 0.3
            return ScoredCandidate(recording: recording, combined: combined)
        }

        guard !candidates.isEmpty else { return nil }

        let sorted = candidates.sorted { $0.combined > $1.combined }
        let best = sorted[0]

        if sorted.count == 1 {
            return makeMatch(from: best.recording, source: .auto)
        }

        let second = sorted[1]
        guard best.combined - second.combined >= scoreMarginForHighConfidence else { return nil }

        return makeMatch(from: best.recording, source: .auto)
    }

    static func normalizeTokens(_ text: String) -> Set<String> {
        let separators = CharacterSet.alphanumerics.inverted
        return Set(
            text.lowercased()
                .components(separatedBy: separators)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count >= minimumTokenLength }
        )
    }

    static func jaccard(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty || !rhs.isEmpty else { return 0 }
        let intersection = lhs.intersection(rhs).count
        let union = lhs.union(rhs).count
        guard union > 0 else { return 0 }
        return Double(intersection) / Double(union)
    }

    private struct ScoredCandidate {
        let recording: PlaudRecording
        let combined: Double
    }

    private static func makeMatch(from recording: PlaudRecording, source: PlaudMatchSource) -> PlaudEventMatch? {
        guard let webURL = webURL(for: recording.fileID) else { return nil }
        return PlaudEventMatch(
            fileID: recording.fileID,
            webURL: webURL,
            confidence: .high,
            source: source
        )
    }

    private static func timeProximityScore(recordedAt: Date, eventStart: Date, eventEnd: Date) -> Double {
        if recordedAt >= eventStart && recordedAt <= eventEnd { return 1 }
        let distance: TimeInterval
        if recordedAt < eventStart {
            distance = eventStart.timeIntervalSince(recordedAt)
        } else {
            distance = recordedAt.timeIntervalSince(eventEnd)
        }
        let maxDistance = max(timeWindowBefore, timeWindowAfter)
        return max(0, 1 - distance / maxDistance)
    }

    private static func titleTokenScore(eventTitle: String, recordingTitle: String) -> Double {
        jaccard(normalizeTokens(eventTitle), normalizeTokens(recordingTitle))
    }
}
