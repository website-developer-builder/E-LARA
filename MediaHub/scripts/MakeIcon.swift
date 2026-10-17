// Draws the placeholder app icon at every size the asset catalog needs.
// Usage: swift scripts/MakeIcon.swift MediaHub/Resources/Assets.xcassets/AppIcon.appiconset
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    // macOS icon grid: ~10% margin, rounded square.
    let inset = s * 0.1
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let tile = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGradient(starting: NSColor(red: 0.33, green: 0.42, blue: 0.98, alpha: 1),
               ending: NSColor(red: 0.62, green: 0.30, blue: 0.93, alpha: 1))!.draw(in: tile, angle: -60)
    // Three glyphs: photo, film, music — one library for all three.
    let symbols = ["photo.fill", "film.fill", "music.note"]
    let glyph = rect.width * 0.27
    let config = NSImage.SymbolConfiguration(pointSize: glyph, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    let positions: [CGPoint] = [
        CGPoint(x: rect.midX - rect.width * 0.2, y: rect.midY + rect.height * 0.14),
        CGPoint(x: rect.midX + rect.width * 0.2, y: rect.midY + rect.height * 0.14),
        CGPoint(x: rect.midX, y: rect.midY - rect.height * 0.2),
    ]
    for (name, center) in zip(symbols, positions) {
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { continue }
        let size = img.size
        img.draw(in: NSRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)@\(scale)x.png"
        try! render(size * scale).write(to: out.appendingPathComponent(name))
        images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(size)x\(size)", "filename": name])
    }
}
let json: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try! JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    .write(to: out.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icon images")
