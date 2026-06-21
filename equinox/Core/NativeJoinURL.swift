import Foundation

/// Pure URL string transforms for native meeting apps (Zoom, Teams, Chime).
/// App installation checks stay in `NativeJoinURLResolver` (requires AppKit).
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
