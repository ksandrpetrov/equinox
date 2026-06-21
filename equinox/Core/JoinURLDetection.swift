import Foundation

/// Detects video-conference join URLs in event text fields.
enum JoinURLDetection {
    private static let linkDetector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    private static let meetingPatterns = MeetingProviderRegistry.allDetectionSubstrings

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
            let link = url.absoluteString.lowercased()
            if meetingPatterns.contains(where: { link.contains($0.lowercased()) }) {
                found = url
                stop.pointee = true
            }
        }
        return found
    }
}
