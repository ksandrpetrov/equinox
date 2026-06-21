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
