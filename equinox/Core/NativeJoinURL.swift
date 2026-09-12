import Foundation

/// Pure URL string transforms for native meeting apps (Zoom, Teams, Chime).
/// App installation checks stay in `NativeJoinURLResolver` (requires AppKit).
enum NativeJoinURL {
    static func nativeURLString(from webURL: URL) -> String? {
        guard let provider = MeetingProviderRegistry.match(for: webURL) else { return nil }
        let scheme = webURL.scheme?.lowercased()

        if scheme == provider.nativeScheme?.replacingOccurrences(of: "://", with: "") {
            return webURL.absoluteString
        }

        switch provider.id {
        case "zoom":
            return zoomNativeURLString(from: webURL)
        case "teams":
            guard var components = URLComponents(url: webURL, resolvingAgainstBaseURL: false),
                  components.host?.lowercased().hasSuffix("teams.microsoft.com") == true,
                  components.path.lowercased().hasPrefix("/l/meetup-join/") else { return nil }
            components.scheme = "msteams"
            return components.url?.absoluteString
        case "chime":
            guard webURL.host()?.lowercased() == "chime.aws" else { return nil }
            let pin = webURL.path.split(separator: "/").first.map(String.init) ?? ""
            guard !pin.isEmpty else { return nil }
            var components = URLComponents()
            components.scheme = "chime"
            components.host = "meeting"
            components.queryItems = [URLQueryItem(name: "pin", value: pin)]
            return components.url?.absoluteString
        default:
            return nil
        }
    }

    static func nativeScheme(for webURL: URL) -> String? {
        guard nativeURLString(from: webURL) != nil else { return nil }
        return MeetingProviderRegistry.match(for: webURL)?.nativeScheme
    }

    private static func zoomNativeURLString(from webURL: URL) -> String? {
        guard let host = webURL.host()?.lowercased(),
              host == "zoom.us" || host.hasSuffix(".zoom.us") ||
                host == "zoomgov.com" || host.hasSuffix(".zoomgov.com") else {
            return nil
        }
        let pathParts = webURL.path.split(separator: "/").map(String.init)
        guard pathParts.count >= 2,
              ["j", "s", "w"].contains(pathParts[0].lowercased()),
              !pathParts[1].isEmpty else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "zoommtg"
        components.host = "zoom.us"
        components.path = "/join"
        var queryItems = [URLQueryItem(name: "confno", value: pathParts[1])]
        queryItems.append(contentsOf: URLComponents(url: webURL, resolvingAgainstBaseURL: false)?.queryItems ?? [])
        components.queryItems = queryItems
        return components.url?.absoluteString
    }
}
