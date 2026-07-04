import Foundation

/// Pure URL string transforms for native meeting apps (Zoom, Teams, Chime).
/// App installation checks stay in `NativeJoinURLResolver` (requires AppKit).
enum NativeJoinURL {
    static func nativeURLString(from webURL: URL) -> String? {
        guard let provider = MeetingProviderRegistry.match(for: webURL) else { return nil }
        let link = webURL.absoluteString

        switch provider.id {
        case "zoom":
            var appLink = link.replacingOccurrences(of: "https://", with: "zoommtg://")
            appLink = appLink.replacingOccurrences(of: "?", with: "&")
            appLink = appLink.replacingOccurrences(of: "/j/", with: "/join?confno=")
            appLink = appLink.replacingOccurrences(of: "/s/", with: "/join?confno=")
            appLink = appLink.replacingOccurrences(of: "/w/", with: "/join?confno=")
            return appLink
        case "teams":
            return link.replacingOccurrences(of: "https://", with: "msteams://")
        case "chime":
            return link.replacingOccurrences(of: "https://chime.aws/", with: "chime://meeting?pin=")
        default:
            return nil
        }
    }

    static func nativeScheme(for webURL: URL) -> String? {
        MeetingProviderRegistry.match(for: webURL)?.nativeScheme
    }
}

extension JoinURLDetection {
    /// Removes detected join URLs from notes so detail views do not duplicate the join action.
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
