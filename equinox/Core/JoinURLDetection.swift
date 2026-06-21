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
