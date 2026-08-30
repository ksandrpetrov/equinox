import AppKit

/// Allows keyboard focus for sheets while keeping the panel non-activating for the rest of the app.
final class KeyablePanel: NSPanel {
    var onCancelOperation: (() -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        if onCancelOperation?() == true {
            return
        }
        super.cancelOperation(sender)
    }
}
