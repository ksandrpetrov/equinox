import Foundation

struct PlaudRecording: Sendable, Equatable, Codable {
    let fileID: String
    let title: String
    let recordedAt: Date
    let durationSeconds: TimeInterval

    var endDate: Date {
        recordedAt.addingTimeInterval(max(0, durationSeconds))
    }

    init(
        fileID: String,
        title: String,
        recordedAt: Date,
        durationSeconds: TimeInterval = 0
    ) {
        self.fileID = fileID
        self.title = title
        self.recordedAt = recordedAt
        self.durationSeconds = max(0, durationSeconds)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileID = try container.decode(String.self, forKey: .fileID)
        title = try container.decode(String.self, forKey: .title)
        recordedAt = try container.decode(Date.self, forKey: .recordedAt)
        durationSeconds = max(0, try container.decodeIfPresent(TimeInterval.self, forKey: .durationSeconds) ?? 0)
    }
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

    static func overlapSeconds(
        recStart: Date,
        recEnd: Date,
        eventStart: Date,
        eventEnd: Date
    ) -> TimeInterval {
        let start = max(recStart, eventStart)
        let end = min(recEnd, eventEnd)
        return max(0, end.timeIntervalSince(start))
    }

    static func assignMatches(
        events: [PlaudMatchableEvent],
        recordings: [PlaudRecording],
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> [String: PlaudEventMatch] {
        let pastEvents = events.filter { $0.endDate < now }
        guard !pastEvents.isEmpty, !recordings.isEmpty else { return [:] }

        var recordingClaims: [RecordingClaim] = []
        for recording in recordings {
            guard let claim = bestClaim(for: recording, among: pastEvents, calendar: calendar) else { continue }
            recordingClaims.append(claim)
        }

        var winnerByEventKey: [String: RecordingClaim] = [:]
        for claim in recordingClaims {
            let key = matchKey(eventIdentifier: claim.event.eventIdentifier, startDate: claim.event.startDate)
            if let existing = winnerByEventKey[key] {
                if claim.rankValue > existing.rankValue
                    || (claim.rankValue == existing.rankValue && claim.tieBreak < existing.tieBreak) {
                    winnerByEventKey[key] = claim
                }
            } else {
                winnerByEventKey[key] = claim
            }
        }

        var results: [String: PlaudEventMatch] = [:]
        for (key, claim) in winnerByEventKey {
            if let match = makeMatch(from: claim.recording, source: .auto) {
                results[key] = match
            }
        }
        return results
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

    private struct RecordingClaim {
        let recording: PlaudRecording
        let event: PlaudMatchableEvent
        let rankValue: Double
        let tieBreak: TimeInterval
    }

    private struct ScoredEventCandidate {
        let event: PlaudMatchableEvent
        let rankValue: Double
        let tieBreak: TimeInterval
        let titleScore: Double
    }

    private static func bestClaim(
        for recording: PlaudRecording,
        among events: [PlaudMatchableEvent],
        calendar: Calendar
    ) -> RecordingClaim? {
        let candidates: [ScoredEventCandidate]
        if recording.durationSeconds > 0 {
            candidates = overlapCandidates(for: recording, among: events, calendar: calendar)
        } else {
            candidates = proximityCandidates(for: recording, among: events, calendar: calendar)
        }

        guard !candidates.isEmpty else { return nil }

        let sorted = candidates.sorted {
            if $0.rankValue != $1.rankValue { return $0.rankValue > $1.rankValue }
            if $0.titleScore != $1.titleScore { return $0.titleScore > $1.titleScore }
            return $0.tieBreak < $1.tieBreak
        }

        let best = sorted[0]
        if sorted.count >= 2 {
            let second = sorted[1]
            let margin = best.rankValue - second.rankValue
            let relativeClose = second.rankValue >= best.rankValue * (1 - scoreMarginForHighConfidence)
            let titleDisambiguates = abs(best.titleScore - second.titleScore) >= scoreMarginForHighConfidence
            if relativeClose && !titleDisambiguates && margin < 60 {
                return nil
            }
        }

        return RecordingClaim(
            recording: recording,
            event: best.event,
            rankValue: best.rankValue,
            tieBreak: best.tieBreak
        )
    }

    private static func overlapCandidates(
        for recording: PlaudRecording,
        among events: [PlaudMatchableEvent],
        calendar: Calendar
    ) -> [ScoredEventCandidate] {
        events.compactMap { event in
            guard calendar.isDate(recording.recordedAt, inSameDayAs: event.startDate) else { return nil }
            let overlap = overlapSeconds(
                recStart: recording.recordedAt,
                recEnd: recording.endDate,
                eventStart: event.startDate,
                eventEnd: event.endDate
            )
            guard overlap > 0 else { return nil }
            let titleScore = titleTokenScore(eventTitle: event.title, recordingTitle: recording.title)
            let tieBreak = abs(recording.recordedAt.timeIntervalSince(event.startDate))
            return ScoredEventCandidate(
                event: event,
                rankValue: overlap,
                tieBreak: tieBreak,
                titleScore: titleScore
            )
        }
    }

    private static func proximityCandidates(
        for recording: PlaudRecording,
        among events: [PlaudMatchableEvent],
        calendar: Calendar
    ) -> [ScoredEventCandidate] {
        events.compactMap { event in
            let recordedAt = recording.recordedAt
            guard calendar.isDate(recordedAt, inSameDayAs: event.startDate) else { return nil }

            let windowStart = event.startDate.addingTimeInterval(-timeWindowBefore)
            let windowEnd = event.endDate.addingTimeInterval(timeWindowAfter)
            guard recordedAt >= windowStart, recordedAt <= windowEnd else { return nil }

            let timeScore = timeProximityScore(
                recordedAt: recordedAt,
                eventStart: event.startDate,
                eventEnd: event.endDate
            )
            let titleScore = titleTokenScore(eventTitle: event.title, recordingTitle: recording.title)
            let combined = timeScore * 0.7 + titleScore * 0.3
            let tieBreak = abs(recordedAt.timeIntervalSince(event.startDate))
            return ScoredEventCandidate(
                event: event,
                rankValue: combined,
                tieBreak: tieBreak,
                titleScore: titleScore
            )
        }
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
