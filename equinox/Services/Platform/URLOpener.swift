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
        if openURL(url) { return true }
        guard let fallback, fallback != url else { return false }
        return openURL(fallback)
    }
}
