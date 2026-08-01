import CoreGraphics
import Foundation

/// Pure RGBA / hex helpers shared by EventKit mapping (no AppKit).
enum ColorHex {
    struct RGBA {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
    }

    static func rgbaToHex(red: CGFloat, green: CGFloat, blue: CGFloat) -> String {
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    static func cgColorComponents(_ cgColor: CGColor) -> RGBA? {
        guard let components = cgColor.components, !components.isEmpty else { return nil }
        let red = components[0]
        let green = components.count > 1 ? components[1] : red
        let blue = components.count > 2 ? components[2] : red
        let alpha = components.count > 3 ? components[3] : 1
        return RGBA(red: red, green: green, blue: blue, alpha: alpha)
    }

    static func hex(from cgColor: CGColor) -> String? {
        guard let rgba = cgColorComponents(cgColor) else { return nil }
        return rgbaToHex(red: rgba.red, green: rgba.green, blue: rgba.blue)
    }
}
