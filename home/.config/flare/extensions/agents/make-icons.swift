// Draws Flare's agent icons from Rex's agent glyphs: each glyph on a
// rounded tile, laid out as Flare draws its symbol tiles.
import AppKit

let rex = Bundle(path: "/Applications/Rex Beta.app/Contents/Resources/SuperBlockIcons_SuperBlockIcons.bundle")!
// Run: swift make-icons.swift <dir of this file>
let out = CommandLine.arguments[1]
let pixels = 64.0
// Flare's row.rs: a tile fills 84% of the icon, its corners round by 24% of
// it, and its glyph fills 60%.
let tileShare = 0.84, radiusShare = 0.24, glyphShare = 0.6

func rgb(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

// app: (Rex's glyph, tile, glyph color)
let agents: [(String, String, Int, Int)] = [
    ("claude-code", "block-glyph-claude", 0xD97757, 0xFFFFFF),
    ("codex", "block-glyph-codex", 0xFFFFFF, 0x000000),
    ("pi", "block-glyph-pi", 0xFFFFFF, 0x000000),
    ("opencode", "block-glyph-opencode", 0xFFFFFF, 0x000000),
]

for (app, name, tile, ink) in agents {
    guard let glyph = rex.image(forResource: name) else { fatalError("no \(name) in Rex") }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(pixels), pixelsHigh: Int(pixels),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let size = pixels * tileShare
    let square = NSRect(x: (pixels - size) / 2, y: (pixels - size) / 2, width: size, height: size)
    rgb(tile).setFill()
    NSBezierPath(roundedRect: square, xRadius: size * radiusShare, yRadius: size * radiusShare).fill()
    // The glyph fitted into its share of the tile, in the ink's color
    let box = size * glyphShare
    let scale = min(box / glyph.size.width, box / glyph.size.height)
    let w = glyph.size.width * scale, h = glyph.size.height * scale
    let tinted = NSImage(size: NSSize(width: w, height: h), flipped: false) { rect in
        glyph.draw(in: rect)
        rgb(ink).setFill()
        rect.fill(using: .sourceAtop)
        return true
    }
    tinted.draw(in: NSRect(x: (pixels - w) / 2, y: (pixels - h) / 2, width: w, height: h))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(app).png"))
}
