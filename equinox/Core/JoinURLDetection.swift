import Foundation

/// Detects video-conference join URLs in event text fields.
enum JoinURLDetection {
    private static let linkDetector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    private static let meetingPatterns = [
        "zoom.us/j/", "zoom.us/s/", "zoom.us/w/", "zoom.us/my/",
        "zoomgov.com/j/", "zoomgov.com/s/", "zoomgov.com/w/", "zoomgov.com/my/",
        "teams.microsoft.com/l/meetup-join/",
        "chime.aws/",
        "zoommtg://", "msteams://", "chime://",
        "meet.google.com/", "hangouts.google.com/", "webex.com/",
        "gotomeeting.com/join", "ringcentral.com/j",
        "bigbluebutton.org/gl", "https://bigbluebutton.", "https://bbb.",
        "https://meet.jit.si/", "indigo.collocall.de", "public.senfcall.de",
        "facetime.apple.com/join", "workplace.com/meet", "youcanbook.me/zoom/",
        "vk.com/call/"
    ]

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
            let link = url.absoluteString
            if meetingPatterns.contains(where: { link.contains($0) }) {
                found = url
                stop.pointee = true
            }
        }
        return found
    }
}

/// Pure URL string transforms for native meeting apps (Zoom, Teams, Chime).
/// App installation checks stay in `CalendarStore` (requires AppKit).
enum NativeJoinURL {
    static func nativeURLString(from webURL: URL) -> String? {
        let link = webURL.absoluteString

        if link.contains("zoom.us/j/") || link.contains("zoom.us/s/") ||
            link.contains("zoom.us/w/") || link.contains("zoom.us/my/") ||
            link.contains("zoomgov.com/j/") || link.contains("zoomgov.com/s/") ||
            link.contains("zoomgov.com/w/") || link.contains("zoomgov.com/my/") {
            var appLink = link.replacingOccurrences(of: "https://", with: "zoommtg://")
            appLink = appLink.replacingOccurrences(of: "?", with: "&")
            appLink = appLink.replacingOccurrences(of: "/j/", with: "/join?confno=")
            appLink = appLink.replacingOccurrences(of: "/s/", with: "/join?confno=")
            appLink = appLink.replacingOccurrences(of: "/w/", with: "/join?confno=")
            return appLink
        }

        if link.contains("teams.microsoft.com/l/meetup-join/") {
            return link.replacingOccurrences(of: "https://", with: "msteams://")
        }

        if link.contains("chime.aws/") {
            return link.replacingOccurrences(of: "https://chime.aws/", with: "chime://meeting?pin=")
        }

        return nil
    }

    static func nativeScheme(for webURL: URL) -> String? {
        let link = webURL.absoluteString
        if link.contains("zoom.us/") || link.contains("zoomgov.com/") {
            return "zoommtg://"
        }
        if link.contains("teams.microsoft.com/l/meetup-join/") {
            return "msteams://"
        }
        if link.contains("chime.aws/") {
            return "chime://"
        }
        return nil
    }
}
