import Foundation

/// GUI presentation helpers for detected join URLs (labels, SF Symbols).
enum JoinURLPresentation {
    static func meetingDisplayName(for url: URL) -> String {
        MeetingProviderRegistry.match(for: url)?.displayName
            ?? String(localized: "Video call", bundle: .equinox, comment: "Generic meeting provider name")
    }

    static func meetingSystemImage(for url: URL) -> String {
        MeetingProviderRegistry.match(for: url)?.systemImage ?? "video.fill"
    }

    static func notesForDisplay(notes: String?, excludingJoinURL joinURL: URL?) -> String? {
        JoinURLDetection.notesForDisplay(notes: notes, excludingJoinURL: joinURL)
    }

    static func sourceJoinURL(
        location: String?,
        eventURL: URL?,
        notes: String?,
        fallback: URL?
    ) -> URL? {
        JoinURLDetection.detectJoinURL(
            location: location,
            url: eventURL?.absoluteString,
            notes: notes
        ) ?? fallback
    }

    static func supplementalEventURL(eventURL: URL?, sourceJoinURL: URL?) -> URL? {
        guard let eventURL else { return nil }
        return eventURL == sourceJoinURL ? nil : eventURL
    }
}
