import Foundation

/// GUI presentation helpers for detected join URLs (labels, SF Symbols).
enum JoinURLPresentation {
    static func meetingDisplayName(for url: URL) -> String {
        MeetingProviderRegistry.match(for: url)?.displayName
            ?? String(localized: "Video call", comment: "Generic meeting provider name")
    }

    static func meetingSystemImage(for url: URL) -> String {
        MeetingProviderRegistry.match(for: url)?.systemImage ?? "video.fill"
    }

    static func notesForDisplay(notes: String?, excludingJoinURL joinURL: URL?) -> String? {
        JoinURLDetection.notesForDisplay(notes: notes, excludingJoinURL: joinURL)
    }
}
