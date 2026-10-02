import AppKit
import Foundation

@MainActor
enum URLOpener {
    @discardableResult
    static func open(
        _ url: URL,
        fallback: URL? = nil,
        using openURL: (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) -> Bool {
        if canOpenEventURL(url), openURL(url) { return true }
        guard let fallback, fallback != url, canOpenEventURL(fallback) else { return false }
        return openURL(fallback)
    }

    private static func canOpenEventURL(_ url: URL) -> Bool {
        guard EventDraftDefaults.absoluteURL(from: url.absoluteString) != nil,
              let scheme = url.scheme?.lowercased() else { return false }
        // Calendar content can come from invitations and subscriptions. Opening a
        // file URL through Launch Services can launch a local app or executable.
        return !["file", "javascript", "data"].contains(scheme)
    }
}
