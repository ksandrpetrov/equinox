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
            guard let pathParts = meetingPathComponents(from: webURL),
                  pathParts.count == 1, let pin = pathParts.first else { return nil }
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
        guard let pathParts = meetingPathComponents(from: webURL), pathParts.count == 2,
              ["j", "s", "w"].contains(pathParts[0].lowercased()),
              !pathParts[1].isEmpty,
              pathParts[1].utf8.allSatisfy({ (48...57).contains($0) }) else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "zoommtg"
        components.host = "zoom.us"
        components.path = "/join"
        var queryItems = [URLQueryItem(name: "confno", value: pathParts[1])]
        // The web path identifies the meeting. Do not let a query parameter add
        // a second, possibly conflicting native meeting ID; preserve other fields.
        // Keep the original percent encoding: decoding %2B and writing '+' can
        // turn an opaque password/token character into a space in the client.
        let sourceItems = URLComponents(url: webURL, resolvingAgainstBaseURL: false)?.percentEncodedQueryItems ?? []
        queryItems.append(contentsOf: sourceItems.filter {
            $0.name.removingPercentEncoding?.lowercased() != "confno"
        })
        components.percentEncodedQueryItems = queryItems
        return components.url?.absoluteString
    }

    private static func meetingPathComponents(from url: URL) -> [String]? {
        guard var path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath,
              path.hasPrefix("/") else { return nil }
        path.removeFirst()
        if path.hasSuffix("/") { path.removeLast() }
        var components: [String] = []
        // Split before decoding: an encoded slash belongs to the identifier and
        // must not disappear along with empty components when forming a native URL.
        for encoded in path.split(separator: "/", omittingEmptySubsequences: false) {
            guard let decoded = String(encoded).removingPercentEncoding,
                  !decoded.isEmpty, !decoded.contains("/") else { return nil }
            components.append(decoded)
        }
        return components
    }
}
