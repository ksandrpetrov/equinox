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
        let r = byte(from: red)
        let g = byte(from: green)
        let b = byte(from: blue)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    static func cgColorComponents(_ cgColor: CGColor) -> RGBA? {
        if let components = cgColor.components, components.count == 2 {
            let white = clamped(components[0])
            return RGBA(
                red: white,
                green: white,
                blue: white,
                alpha: clamped(components[1])
            )
        }

        if let components = cgColor.components,
           components.count >= 3,
           isSRGB(cgColor.colorSpace) {
            return rgba(from: components)
        }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = cgColor.converted(
                to: colorSpace,
                intent: .defaultIntent,
                options: nil
              ),
              let components = converted.components,
              components.count >= 3 else {
            return nil
        }
        return rgba(from: components)
    }

    private static func rgba(from components: [CGFloat]) -> RGBA {
        return RGBA(
            red: clamped(components[0]),
            green: clamped(components[1]),
            blue: clamped(components[2]),
            alpha: clamped(components.count > 3 ? components[3] : 1)
        )
    }

    private static func isSRGB(_ colorSpace: CGColorSpace?) -> Bool {
        guard let name = colorSpace?.name else { return false }
        return name == CGColorSpace.sRGB || name == CGColorSpace.extendedSRGB
    }

    static func hex(from cgColor: CGColor) -> String? {
        guard let rgba = cgColorComponents(cgColor) else { return nil }
        return rgbaToHex(red: rgba.red, green: rgba.green, blue: rgba.blue)
    }

    private static func byte(from component: CGFloat) -> Int {
        Int(round(clamped(component) * 255))
    }

    private static func clamped(_ component: CGFloat) -> CGFloat {
        min(max(component, 0), 1)
    }
}
