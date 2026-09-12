import AppKit

// A graphics-capable XCTest host with no application delegate or calendar access.
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
application.run()
