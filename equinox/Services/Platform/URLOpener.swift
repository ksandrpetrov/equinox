import AppKit
import Foundation

@MainActor
enum URLOpener {
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
