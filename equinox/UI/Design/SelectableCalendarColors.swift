import AppKit
import SwiftUI

extension SelectableCalendar {
    var color: NSColor {
        NSColor(red: colorRed, green: colorGreen, blue: colorBlue, alpha: colorAlpha)
    }

    var swiftUIColor: Color {
        Color(red: colorRed, green: colorGreen, blue: colorBlue, opacity: colorAlpha)
    }
}
