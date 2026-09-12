import Foundation

/// Canonical meeting-provider registry shared by join URL detection, native rewrite, and UI labels.
struct MeetingProvider: Sendable, Equatable {
    let id: String
    let detectionSubstrings: [String]
    let nativeScheme: String?
    let displayName: String
    let systemImage: String

    func matches(_ url: URL) -> Bool {
        detectionSubstrings.contains { Self.matches(url, pattern: $0) }
    }

    private static func matches(_ url: URL, pattern rawPattern: String) -> Bool {
        let pattern = rawPattern.lowercased()
        if let schemeSeparator = pattern.range(of: "://") {
            let expectedScheme = String(pattern[..<schemeSeparator.lowerBound])
            if expectedScheme != "http" && expectedScheme != "https" {
                guard url.scheme?.lowercased() == expectedScheme else { return false }
                let resourcePattern = String(pattern[schemeSeparator.upperBound...])
                let pieces = resourcePattern.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
                guard let expectedHost = pieces.first, !expectedHost.isEmpty,
                      let actualHost = url.host()?.lowercased(),
                      actualHost == String(expectedHost) else { return false }
                guard pieces.count == 2 else { return true }
                return url.path.lowercased().hasPrefix("/" + pieces[1])
            }
        }

        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host()?.lowercased() else {
            return false
        }

        let withoutScheme = pattern
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        let pieces = withoutScheme.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let hostPattern = String(pieces[0])
        let pathPattern = pieces.count == 2 ? "/" + pieces[1] : nil

        let hostMatches: Bool
        if hostPattern.hasSuffix(".") {
            hostMatches = host.hasPrefix(hostPattern)
        } else {
            hostMatches = host == hostPattern || host.hasSuffix("." + hostPattern)
        }
        guard hostMatches else { return false }

        guard let pathPattern else { return true }
        return url.path.lowercased().hasPrefix(pathPattern)
    }
}

enum MeetingProviderRegistry {
    static let all: [MeetingProvider] = [
        MeetingProvider(
            id: "zoom",
            detectionSubstrings: [
                "zoom.us/j/", "zoom.us/s/", "zoom.us/w/", "zoom.us/my/",
                "zoomgov.com/j/", "zoomgov.com/s/", "zoomgov.com/w/", "zoomgov.com/my/",
                "zoommtg://zoom.us/join", "youcanbook.me/zoom/",
            ],
            nativeScheme: "zoommtg://",
            displayName: String(localized: "Zoom", bundle: .equinox, comment: "Meeting provider name"),
            systemImage: "video.fill"
        ),
        MeetingProvider(
            id: "teams",
            detectionSubstrings: [
                "teams.microsoft.com/l/meetup-join/",
                "teams.microsoft.com/meet/",
                "msteams://teams.microsoft.com/l/meetup-join/",
            ],
            nativeScheme: "msteams://",
            displayName: String(localized: "Microsoft Teams", bundle: .equinox, comment: "Meeting provider name"),
            systemImage: "person.2.fill"
        ),
        MeetingProvider(
            id: "chime",
            detectionSubstrings: [
                "chime.aws/",
                "chime://meeting",
            ],
            nativeScheme: "chime://",
            displayName: String(localized: "Amazon Chime", bundle: .equinox, comment: "Meeting provider name"),
            systemImage: "phone.fill"
        ),
        MeetingProvider(
            id: "googleMeet",
            detectionSubstrings: [
                "meet.google.com/",
                "hangouts.google.com/",
            ],
            nativeScheme: nil,
            displayName: String(localized: "Google Meet", bundle: .equinox, comment: "Meeting provider name"),
            systemImage: "video.fill"
        ),
        MeetingProvider(
            id: "webex",
            detectionSubstrings: ["webex.com/"],
            nativeScheme: nil,
            displayName: String(localized: "Webex", bundle: .equinox, comment: "Meeting provider name"),
            systemImage: "video.fill"
        ),
        MeetingProvider(
            id: "vk",
            detectionSubstrings: ["vk.com/call/"],
            nativeScheme: nil,
            displayName: String(localized: "VK Calls", bundle: .equinox, comment: "Meeting provider name"),
            systemImage: "phone.fill"
        ),
        MeetingProvider(
            id: "facetime",
            detectionSubstrings: ["facetime.apple.com/join"],
            nativeScheme: nil,
            displayName: String(localized: "FaceTime", bundle: .equinox, comment: "Meeting provider name"),
            systemImage: "facetime"
        ),
        MeetingProvider(
            id: "other",
            detectionSubstrings: [
                "gotomeeting.com/join", "ringcentral.com/j",
                "bigbluebutton.org/gl", "https://bigbluebutton.", "https://bbb.",
                "https://meet.jit.si/", "indigo.collocall.de", "public.senfcall.de",
                "workplace.com/meet",
            ],
            nativeScheme: nil,
            displayName: String(localized: "Video call", bundle: .equinox, comment: "Generic meeting provider name"),
            systemImage: "video.fill"
        ),
    ]

    static var allDetectionSubstrings: [String] {
        all.flatMap(\.detectionSubstrings)
    }

    static func match(for url: URL) -> MeetingProvider? {
        all.first { $0.matches(url) }
    }
}
