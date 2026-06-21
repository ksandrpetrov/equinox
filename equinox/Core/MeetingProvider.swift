import Foundation

/// Canonical meeting-provider registry shared by join URL detection, native rewrite, and UI labels.
struct MeetingProvider: Sendable, Equatable {
    let id: String
    let detectionSubstrings: [String]
    let nativeScheme: String?
    let displayName: String
    let systemImage: String

    func matches(_ url: URL) -> Bool {
        let link = url.absoluteString.lowercased()
        return detectionSubstrings.contains { link.contains($0.lowercased()) }
    }
}

enum MeetingProviderRegistry {
    static let all: [MeetingProvider] = [
        MeetingProvider(
            id: "zoom",
            detectionSubstrings: [
                "zoom.us/j/", "zoom.us/s/", "zoom.us/w/", "zoom.us/my/",
                "zoomgov.com/j/", "zoomgov.com/s/", "zoomgov.com/w/", "zoomgov.com/my/",
                "zoommtg://", "youcanbook.me/zoom/",
            ],
            nativeScheme: "zoommtg://",
            displayName: String(localized: "Zoom", comment: "Meeting provider name"),
            systemImage: "video.fill"
        ),
        MeetingProvider(
            id: "teams",
            detectionSubstrings: [
                "teams.microsoft.com/l/meetup-join/",
                "msteams://",
            ],
            nativeScheme: "msteams://",
            displayName: String(localized: "Microsoft Teams", comment: "Meeting provider name"),
            systemImage: "person.2.fill"
        ),
        MeetingProvider(
            id: "chime",
            detectionSubstrings: [
                "chime.aws/",
                "chime://",
            ],
            nativeScheme: "chime://",
            displayName: String(localized: "Amazon Chime", comment: "Meeting provider name"),
            systemImage: "phone.fill"
        ),
        MeetingProvider(
            id: "googleMeet",
            detectionSubstrings: [
                "meet.google.com/",
                "hangouts.google.com/",
            ],
            nativeScheme: nil,
            displayName: String(localized: "Google Meet", comment: "Meeting provider name"),
            systemImage: "video.fill"
        ),
        MeetingProvider(
            id: "webex",
            detectionSubstrings: ["webex.com/"],
            nativeScheme: nil,
            displayName: String(localized: "Webex", comment: "Meeting provider name"),
            systemImage: "video.fill"
        ),
        MeetingProvider(
            id: "vk",
            detectionSubstrings: ["vk.com/call/"],
            nativeScheme: nil,
            displayName: String(localized: "VK Calls", comment: "Meeting provider name"),
            systemImage: "phone.fill"
        ),
        MeetingProvider(
            id: "facetime",
            detectionSubstrings: ["facetime.apple.com/join"],
            nativeScheme: nil,
            displayName: String(localized: "FaceTime", comment: "Meeting provider name"),
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
            displayName: String(localized: "Video call", comment: "Generic meeting provider name"),
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
