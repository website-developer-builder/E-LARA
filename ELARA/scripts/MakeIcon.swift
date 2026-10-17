// Builds the macOS app icon (and the in-app logo) from the E-LARA brand sheet.
// Crops the rounded icon tile out of the sheet, masks its corners to transparency,
// and renders every size on Apple's icon grid (tile = 824 of 1024 px, soft shadow).
//
// Usage:
//   swift scripts/MakeIcon.swift <brand-sheet.png> <x> <y> <width> <height> <AppIcon.appiconset> <AppLogo.imageset>
// Current crop (Branding/E-LARA-brand-sheet.png): 70 95 468 455
import AppKit

let args = CommandLine.arguments
let sheet = NSImage(contentsOfFile: args[1])!
let crop = CGRect(x: Double(args[2])!, y: Double(args[3])!, width: Double(args[4])!, height: Double(args[5])!)
let iconSet = URL(fileURLWithPath: args[6])
let logoSet = URL(fileURLWithPath: args[7])

let sourceRep = NSBitmapImageRep(data: sheet.tiffRepresentation!)!
let full = sourceRep.cgImage!
// CGImage coordinates are top-left origin for cropping.
let tile = full.cropping(to: crop.integral)!

/// Draws the tile as a rounded square of `side` px, optionally inset on a canvas of `canvas` px with a shadow.
func render(canvas: Int, tileSide: CGFloat, shadow: Bool) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    let c = CGFloat(canvas)
    let rect = CGRect(x: (c - tileSide) / 2, y: (c - tileSide) / 2 + (shadow ? tileSide * 0.012 : 0),
                      width: tileSide, height: tileSide)
    let path = NSBezierPath(roundedRect: rect, xRadius: tileSide * 0.225, yRadius: tileSide * 0.225)
    if shadow {
        NSGraphicsContext.saveGraphicsState()
        let s = NSShadow()
        s.shadowColor = NSColor.black.withAlphaComponent(0.28)
        s.shadowBlurRadius = tileSide * 0.03
        s.shadowOffset = NSSize(width: 0, height: -tileSide * 0.012)
        s.set()
        NSColor.white.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
    path.addClip()
    // Slightly overscan the crop so the sheet's own soft tile edge is clipped away cleanly.
    let over = tileSide * 0.02
    NSImage(cgImage: tile, size: .zero).draw(in: rect.insetBy(dx: -over, dy: -over))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = size * scale
        let name = "icon_\(size)x\(size)@\(scale)x.png"
        try! render(canvas: px, tileSide: CGFloat(px) * 824 / 1024, shadow: px >= 64).write(to: iconSet.appendingPathComponent(name))
        images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(size)x\(size)", "filename": name])
    }
}
try! JSONSerialization.data(withJSONObject: ["images": images, "info": ["author": "xcode", "version": 1]],
                            options: [.prettyPrinted, .sortedKeys]).write(to: iconSet.appendingPathComponent("Contents.json"))

// In-app logo (welcome screen): the tile alone, transparent corners.
try? FileManager.default.createDirectory(at: logoSet, withIntermediateDirectories: true)
try! render(canvas: 240, tileSide: 240, shadow: false).write(to: logoSet.appendingPathComponent("AppLogo.png"))
try! render(canvas: 480, tileSide: 480, shadow: false).write(to: logoSet.appendingPathComponent("AppLogo@2x.png"))
let logoImages: [[String: String]] = [
    ["idiom": "universal", "scale": "1x", "filename": "AppLogo.png"],
    ["idiom": "universal", "scale": "2x", "filename": "AppLogo@2x.png"],
]
try! JSONSerialization.data(withJSONObject: ["images": logoImages, "info": ["author": "xcode", "version": 1]],
                            options: [.prettyPrinted, .sortedKeys]).write(to: logoSet.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icon sizes and the in-app logo")
