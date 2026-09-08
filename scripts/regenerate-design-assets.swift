#!/usr/bin/env swift

import AppKit
import Foundation

let scriptPath = URL(fileURLWithPath: CommandLine.arguments[0])
let scriptURL: URL
if scriptPath.path.hasPrefix("/") {
    scriptURL = scriptPath
} else {
    scriptURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(CommandLine.arguments[0])
}

let rootURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let sourceMarkURL = rootURL.appendingPathComponent("scripts/assets/equinox-mark.png")
let appIconURL = rootURL.appendingPathComponent("equinox/Images.xcassets/AppIcon.appiconset")
let appLogoURL = rootURL.appendingPathComponent("equinox/Images.xcassets/AppLogo.imageset")

let iconSizes: [(String, Int)] = [
    ("AppIcon16.png", 16),
    ("AppIcon16@2x.png", 32),
    ("AppIcon32.png", 32),
    ("AppIcon32@2x.png", 64),
    ("AppIcon128.png", 128),
    ("AppIcon128@2x.png", 256),
    ("AppIcon256.png", 256),
    ("AppIcon256@2x.png", 512),
    ("AppIcon512.png", 512),
    ("AppIcon512@2x.png", 1024),
]

let iconMarginRatio: CGFloat = 0.098
let iconCornerRatio: CGFloat = 0.2237
// Graphite icon tile; UI surfaces continue to use system semantic colors.
let iconBackground = NSColor(calibratedRed: 30 / 255, green: 31 / 255, blue: 34 / 255, alpha: 1)

/// Geometric master: equal light and shadow, separated by a solar horizon.
/// Drawn at the destination size so the mark stays crisp in small icons.
func drawEquinoxMark(in canvas: NSRect) {
    let side = canvas.width
    let diameter = side * 0.52
    let circle = NSRect(x: (side - diameter) / 2, y: (side - diameter) / 2,
                        width: diameter, height: diameter)
    let light = NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.96, alpha: 1)
    let shade = NSColor(calibratedRed: 0.34, green: 0.38, blue: 0.43, alpha: 1)
    let solar = NSColor(calibratedRed: 0.91, green: 0.69, blue: 0.35, alpha: 1)

    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(ovalIn: circle).addClip()
    shade.setFill()
    circle.fill()
    light.setFill()
    NSRect(x: circle.minX, y: side / 2, width: diameter, height: diameter / 2).fill()
    NSGraphicsContext.restoreGraphicsState()

    let horizonHeight = max(1, round(side * 0.024))
    let horizon = NSRect(x: side * 0.19, y: round((side - horizonHeight) / 2),
                        width: side * 0.62, height: horizonHeight)
    solar.setFill()
    NSBezierPath(roundedRect: horizon, xRadius: horizonHeight / 2, yRadius: horizonHeight / 2).fill()
}

func renderAppIcon(size: Int, includesTile: Bool = true) throws -> NSBitmapImageRep {
    let side = CGFloat(size)
    let canvas = NSRect(x: 0, y: 0, width: side, height: side)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(
            domain: "RegenerateDesignAssets",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap context for \(size)x\(size)"]
        )
    }
    bitmap.size = NSSize(width: side, height: side)

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(
            domain: "RegenerateDesignAssets",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to create graphics context for \(size)x\(size)"]
        )
    }
    context.imageInterpolation = .high
    NSGraphicsContext.current = context

    if includesTile {
        let margin = max(1, round(side * iconMarginRatio))
        let panelRect = canvas.insetBy(dx: margin, dy: margin)
        let cornerRadius = max(2, round(panelRect.width * iconCornerRatio))
        let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: cornerRadius, yRadius: cornerRadius)
        iconBackground.setFill()
        panelPath.fill()
    }
    drawEquinoxMark(in: canvas)

    return bitmap
}

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(
            domain: "RegenerateDesignAssets",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to write PNG at \(url.path)"]
        )
    }
    try data.write(to: url, options: .atomic)
}

func writeAppLogoContents() throws {
    let contents = """
    {
      "images" : [
        {
          "filename" : "AppLogo.png",
          "idiom" : "universal",
          "scale" : "1x"
        },
        {
          "filename" : "AppLogo@2x.png",
          "idiom" : "universal",
          "scale" : "2x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }

    """
    try contents.write(
        to: appLogoURL.appendingPathComponent("Contents.json"),
        atomically: true,
        encoding: .utf8
    )
}

do {
    try writePNG(try renderAppIcon(size: 1024, includesTile: false), to: sourceMarkURL)
    for (filename, size) in iconSizes {
        try writePNG(try renderAppIcon(size: size), to: appIconURL.appendingPathComponent(filename))
    }

    try writePNG(try renderAppIcon(size: 256), to: appLogoURL.appendingPathComponent("AppLogo.png"))
    try writePNG(try renderAppIcon(size: 512), to: appLogoURL.appendingPathComponent("AppLogo@2x.png"))
    try writeAppLogoContents()

    print("Regenerated AppIcon, AppLogo and mark from the geometric master in this script")
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
