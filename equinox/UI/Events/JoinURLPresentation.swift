import Foundation

/// GUI presentation helpers for detected join URLs (labels, SF Symbols, notes de-duplication).
enum JoinURLPresentation {
    static func meetingDisplayName(for url: URL) -> String {
        MeetingProviderRegistry.match(for: url)?.displayName
            ?? String(localized: "Video call", comment: "Generic meeting provider name")
    }

    static func meetingSystemImage(for url: URL) -> String {
        MeetingProviderRegistry.match(for: url)?.systemImage ?? "video.fill"
    }

    /// Removes detected join URLs from notes so the detail sheet does not duplicate the join action.
    static func notesForDisplay(notes: String?, excludingJoinURL joinURL: URL?) -> String? {
        guard var text = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        guard let joinURL else { return text }

        var candidates = [joinURL.absoluteString]
        if let native = NativeJoinURL.nativeURLString(from: joinURL) {
            candidates.append(native)
        }
        if joinURL.scheme == "zoommtg" || joinURL.scheme == "msteams" || joinURL.scheme == "chime" {
            candidates.append(joinURL.absoluteString.replacingOccurrences(of: "zoommtg://", with: "https://"))
        }

        for candidate in Set(candidates) {
            text = text.replacingOccurrences(of: candidate, with: "")
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
