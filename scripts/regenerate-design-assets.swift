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
let iconBackground = NSColor(calibratedRed: 30 / 255, green: 31 / 255, blue: 34 / 255, alpha: 1)
let iconEdge = NSColor.white.withAlphaComponent(0.10)

guard let sourceMark = NSImage(contentsOf: sourceMarkURL) else {
    fputs("Missing source mark: \(sourceMarkURL.path)\n", stderr)
    exit(1)
}

func renderAppIcon(size: Int) throws -> NSBitmapImageRep {
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

    let margin = max(1, round(side * iconMarginRatio))
    let panelRect = canvas.insetBy(dx: margin, dy: margin)
    let cornerRadius = max(2, round(panelRect.width * iconCornerRatio))
    let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: cornerRadius, yRadius: cornerRadius)

    iconBackground.setFill()
    panelPath.fill()

    panelPath.lineWidth = max(1, round(side / 512))
    iconEdge.setStroke()
    panelPath.stroke()

    sourceMark.draw(
        in: canvas,
        from: NSRect(origin: .zero, size: sourceMark.size),
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high]
    )

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
    for (filename, size) in iconSizes {
        try writePNG(try renderAppIcon(size: size), to: appIconURL.appendingPathComponent(filename))
    }

    try writePNG(try renderAppIcon(size: 256), to: appLogoURL.appendingPathComponent("AppLogo.png"))
    try writePNG(try renderAppIcon(size: 512), to: appLogoURL.appendingPathComponent("AppLogo@2x.png"))
    try writeAppLogoContents()

    print("Regenerated AppIcon and AppLogo from \(sourceMarkURL.path)")
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
