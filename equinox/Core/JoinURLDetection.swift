import Foundation

/// Detects video-conference join URLs in event text fields.
enum JoinURLDetection {
    private static let linkDetector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    static func detectJoinURL(location: String?, url: String?, notes: String?) -> URL? {
        if let location, let found = detectJoinURL(in: location) { return found }
        if let url, let found = detectJoinURL(in: url) { return found }
        if let notes, let found = detectJoinURL(in: notes) { return found }
        return nil
    }

    static func detectJoinURL(in text: String) -> URL? {
        guard let detector = linkDetector else { return nil }
        var found: URL?
        detector.enumerateMatches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: text.utf16.count)
        ) { result, _, stop in
            guard let result, let url = result.url else { return }
            if MeetingProviderRegistry.match(for: url) != nil {
                found = url
                stop.pointee = true
            }
        }
        return found
    }
}

extension JoinURLDetection {
    /// Removes detected join URLs from notes so detail views do not duplicate the join action.
    static func notesForDisplay(notes: String?, excludingJoinURL joinURL: URL?) -> String? {
        guard var text = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        guard let joinURL else { return text }

        var candidates: Set<URL> = [joinURL]
        if let native = NativeJoinURL.nativeURLString(from: joinURL), let nativeURL = URL(string: native) {
            candidates.insert(nativeURL)
        }
        // Remove complete detected links only: a meeting URL may be a prefix of
        // another meeting, a password-bearing URL, or a parameter inside another link.
        let matches = linkDetector?.matches(
            in: text, range: NSRange(text.startIndex..., in: text)
        ) ?? []
        for match in matches.reversed() {
            guard let url = match.url, candidates.contains(url),
                  let range = Range(match.range, in: text) else { continue }
            text.removeSubrange(range)
        }
        text = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text.isEmpty ? nil : text
    }
}
