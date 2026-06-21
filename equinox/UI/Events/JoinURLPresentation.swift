import Foundation

/// GUI presentation helpers for detected join URLs (labels, SF Symbols, notes de-duplication).
enum JoinURLPresentation {
    static func meetingDisplayName(for url: URL) -> String {
        let link = url.absoluteString.lowercased()
        if link.contains("zoom.us/") || link.contains("zoomgov.com/") || link.hasPrefix("zoommtg://") {
            return String(localized: "Zoom", comment: "Meeting provider name")
        }
        if link.contains("teams.microsoft.com/") || link.hasPrefix("msteams://") {
            return String(localized: "Microsoft Teams", comment: "Meeting provider name")
        }
        if link.contains("chime.aws/") || link.hasPrefix("chime://") {
            return String(localized: "Amazon Chime", comment: "Meeting provider name")
        }
        if link.contains("meet.google.com/") || link.contains("hangouts.google.com/") {
            return String(localized: "Google Meet", comment: "Meeting provider name")
        }
        if link.contains("webex.com/") {
            return String(localized: "Webex", comment: "Meeting provider name")
        }
        if link.contains("vk.com/call/") {
            return String(localized: "VK Calls", comment: "Meeting provider name")
        }
        if link.contains("facetime.apple.com/") {
            return String(localized: "FaceTime", comment: "Meeting provider name")
        }
        return String(localized: "Video call", comment: "Generic meeting provider name")
    }

    static func meetingSystemImage(for url: URL) -> String {
        let link = url.absoluteString.lowercased()
        if link.contains("zoom") { return "video.fill" }
        if link.contains("teams.microsoft.com/") || link.hasPrefix("msteams://") { return "person.2.fill" }
        if link.contains("chime") { return "phone.fill" }
        if link.contains("meet.google.com/") || link.contains("hangouts.google.com/") { return "video.fill" }
        if link.contains("webex.com/") { return "video.fill" }
        if link.contains("vk.com/call/") { return "phone.fill" }
        if link.contains("facetime.apple.com/") { return "facetime" }
        return "video.fill"
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
