// Draws Flare's agent icons from Rex's agent glyphs: each glyph on a
// rounded tile, laid out as Flare draws its symbol tiles: plain for done,
// and for each other state an animated WebP (img2webp packs them) with a
// border of its color, which breathes, or for unread has a sheen, or for working
// chases round while the glyph moves.
import AppKit

let rex = Bundle(path: "/Applications/Rex Beta.app/Contents/Resources/SuperBlockIcons_SuperBlockIcons.bundle")!
// Run: swift make-icons.swift <dir of this file>
let out = CommandLine.arguments[1]
let pixels = 64.0
// As Flare's row.rs draws a tile, its corners round by 24% of it and its
// glyph fills 60%, but it fills 80% of the icon (not 84%), leaving room
// round it for a border
let tileShare = 0.8, radiusShare = 0.24, glyphShare = 0.6
// A border's width and the clear gap between it and the tile, in pixels
let borderWidth = 5.0, borderGap = 1.2
// The animations' frames a second, and the seconds of a breath, of a
// chase's lap, and of a sheen's sweep and the rest before it
let fps = 30.0, breath = 4.0, lap = 1.5, sweep = 1.4, rest = 2.0

func rgb(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

// state: its border's color, as agents.lua's STATES
let states: [(String, Int)] = [
    ("blocked", 0xFF3B30), ("error", 0xAF52DE), ("unread", 0x30B0C7), ("working", 0xFF9500),
]

// A row (from the top) or column (from the left) of a pixel glyph's cells,
// slid one cell right or down (+1) or back (-1), its cells wrapping around
struct Move {
    let column: Bool, index: Int, step: Int
    var undo: Move { Move(column: column, index: index, step: -step) }
}

enum Motion {
    // Turns a full circle while it breathes
    case turn
    // Its cells, columns by rows, slide like a Rubik's cube's, then slide back
    case slide(columns: Int, rows: Int, moves: [Move])
}

// app: (Rex's glyph, tile, glyph color, how it moves while working)
let agents: [(String, String, Int, Int, Motion)] = [
    ("claude-code", "block-glyph-claude", 0xD97757, 0xFFFFFF, .turn),
    ("codex", "block-glyph-codex", 0xFFFFFF, 0x000000, .turn),
    ("pi", "block-glyph-pi", 0xFFFFFF, 0x000000, .slide(columns: 4, rows: 4, moves: [
        Move(column: false, index: 0, step: 1), Move(column: true, index: 1, step: 1),
        Move(column: false, index: 3, step: -1),
    ])),
    ("opencode", "block-glyph-opencode", 0xFFFFFF, 0x000000, .slide(columns: 4, rows: 5, moves: [
        Move(column: false, index: 1, step: 1), Move(column: true, index: 2, step: -1),
        Move(column: false, index: 3, step: -1),
    ])),
]

func ease(_ t: Double) -> Double { t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2 }

// The glyph in the ink's color, at the size it shows on the tile
func tint(_ glyph: NSImage, _ ink: Int) -> NSImage {
    let box = pixels * tileShare * glyphShare
    let scale = min(box / glyph.size.width, box / glyph.size.height)
    return NSImage(size: NSSize(width: glyph.size.width * scale, height: glyph.size.height * scale),
                   flipped: false) { rect in
        glyph.draw(in: rect)
        rgb(ink).setFill()
        rect.fill(using: .sourceAtop)
        return true
    }
}

// Where an image shows centered on the icon
func centered(_ image: NSImage) -> NSRect {
    NSRect(x: (pixels - image.size.width) / 2, y: (pixels - image.size.height) / 2,
           width: image.size.width, height: image.size.height)
}

// A pixel glyph's cells, columns by rows from the top left, as the share of
// each its ink covers. They are read from a large render, since AppKit draws
// a glyph's small sizes from bitmaps of art that differs a little.
func sampled(_ glyph: NSImage, columns: Int, rows: Int) -> [[Double]] {
    let n = 512
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: n, pixelsHigh: n, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    glyph.draw(in: NSRect(x: 0, y: 0, width: n, height: n))
    NSGraphicsContext.restoreGraphicsState()
    // The cells span the glyph's opaque pixels (colorAt counts rows from the top)
    var minX = n, minY = n, maxX = -1, maxY = -1
    for y in 0..<n {
        for x in 0..<n where rep.colorAt(x: x, y: y)!.alphaComponent > 0.5 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    let cw = Double(maxX - minX + 1) / Double(columns), ch = Double(maxY - minY + 1) / Double(rows)
    // Each cell's mean alpha over its middle half, clear of its neighbors' edges
    return (0..<rows).map { r in
        (0..<columns).map { c in
            let xs = Int(Double(minX) + (Double(c) + 0.25) * cw)..<Int(Double(minX) + (Double(c) + 0.75) * cw)
            let ys = Int(Double(minY) + (Double(r) + 0.25) * ch)..<Int(Double(minY) + (Double(r) + 0.75) * ch)
            var sum = 0.0
            for y in ys { for x in xs { sum += rep.colorAt(x: x, y: y)!.alphaComponent } }
            return sum / Double(xs.count * ys.count)
        }
    }
}

// A border in one frame: it paints the ring, which clips what it draws
typealias Border = (CGContext) -> Void

// A border whose color at each angle round the tile, in radians
// counterclockwise from the right, is `color`'s
func around(_ color: @escaping (Double) -> NSColor) -> Border {
    { cg in
        // Thin wedges from the center, each its angle's color; they overlap
        // so no seam shows, and each replaces what it covers
        let wedges = 180, center = CGPoint(x: pixels / 2, y: pixels / 2)
        cg.setBlendMode(.copy)
        for w in 0..<wedges {
            let start = 2 * .pi * Double(w) / Double(wedges), end = start + 2 * .pi / Double(wedges) * 1.5
            cg.setFillColor(color(start).cgColor)
            cg.move(to: center)
            cg.addArc(center: center, radius: pixels, startAngle: start, endAngle: end, clockwise: false)
            cg.closePath()
            cg.fillPath()
        }
    }
}

// How far round from angle `a` angle `b` is, counterclockwise, from 0 to 1
func turns(_ a: Double, _ b: Double) -> Double {
    let t = (b - a) / (2 * .pi)
    return t - t.rounded(.down)
}

// An icon: the tile, the glyph that `paint` draws, and the border
func icon(tile: Int, border: Border?, paint: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(pixels), pixelsHigh: Int(pixels),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let size = pixels * tileShare
    let square = NSRect(x: (pixels - size) / 2, y: (pixels - size) / 2, width: size, height: size)
    rgb(tile).setFill()
    NSBezierPath(roundedRect: square, xRadius: size * radiusShare, yRadius: size * radiusShare).fill()
    NSGraphicsContext.saveGraphicsState()
    paint()
    NSGraphicsContext.restoreGraphicsState()
    if let border {
        // The border rounds with the tile, a clear gap outside it, so it
        // stands apart from a tile of a like color
        let inset = borderGap + borderWidth / 2
        let ring = square.insetBy(dx: -inset, dy: -inset)
        let radius = size * radiusShare + inset
        let cg = context.cgContext
        cg.addPath(CGPath(roundedRect: ring, cornerWidth: radius, cornerHeight: radius, transform: nil))
        cg.setLineWidth(borderWidth)
        cg.replacePathWithStrokedPath()
        cg.clip()
        border(cg)
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(_ rep: NSBitmapImageRep, to file: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: file))
}

// The glyph turned by `turn` of a circle and scaled by `scale` about its center
func turned(_ glyph: NSImage, turn: Double, scale: Double) {
    let rect = centered(glyph)
    let transform = NSAffineTransform()
    transform.translateX(by: rect.midX, yBy: rect.midY)
    transform.rotate(byDegrees: -360 * turn)
    transform.scale(by: scale)
    transform.translateX(by: -rect.midX, yBy: -rect.midY)
    transform.concat()
    glyph.draw(in: rect)
}

// A turn: one circle in three seconds, the glyph breathing to 90% and back
func turnFrames(_ glyph: NSImage) -> [() -> Void] {
    let count = Int(3 * fps)
    return (0..<count).map { i in
        let t = Double(i) / Double(count)
        return { turned(glyph, turn: t, scale: 0.95 + 0.05 * cos(2 * .pi * t)) }
    }
}

// A slide: a pause on the glyph, its moves, a pause, and the moves undone,
// each eased over 0.4 s with 0.1 s after it. Its cells are squares of whole
// pixels that slide a pixel at a time, so they stay crisp and show no seams.
func slideFrames(_ glyph: NSImage, ink: Int, columns: Int, rows: Int, moves: [Move]) -> [() -> Void] {
    var steps: [(Move?, Double)] = [(nil, 0.9)]
    for move in moves { steps += [(move, 0.4), (nil, 0.1)] }
    steps.append((nil, 0.2))
    for move in moves.reversed() { steps += [(move.undo, 0.4), (nil, 0.1)] }
    let cell = 6
    let shares = sampled(glyph, columns: columns, rows: rows)
    // Where the cells show on the icon, centered
    let box = NSRect(x: (Int(pixels) - cell * columns) / 2, y: (Int(pixels) - cell * rows) / 2,
                     width: cell * columns, height: cell * rows)
    // Each place's cell, by row and column from the top left, as (row, column) of the glyph
    var grid = (0..<rows).map { r in (0..<columns).map { c in (r, c) } }
    var frames: [() -> Void] = []
    for (move, seconds) in steps {
        let count = Int((seconds * fps).rounded())
        for i in 0..<count {
            let shift = move.map { Int((ease(Double(i) / Double(count)) * Double(cell)).rounded()) * $0.step } ?? 0
            let cells = grid
            frames.append {
                // Cells are clipped to the glyph, so one sliding off an edge
                // shows coming back at the other
                NSBezierPath(rect: box).addClip()
                for r in 0..<rows {
                    for c in 0..<columns {
                        let (sr, sc) = cells[r][c]
                        var x = Int(box.minX) + c * cell, y = Int(box.minY) + (rows - 1 - r) * cell
                        // Where it shows, and where its copy coming back in does
                        var copies = [(0, 0)]
                        if let move, move.column ? move.index == c : move.index == r {
                            if move.column {
                                y -= shift
                                copies.append((0, move.step * rows * cell))
                            } else {
                                x += shift
                                copies.append((-move.step * columns * cell, 0))
                            }
                        }
                        rgb(ink).withAlphaComponent(shares[sr][sc]).setFill()
                        for (dx, dy) in copies {
                            NSRect(x: x + dx, y: y + dy, width: cell, height: cell).fill(using: .sourceOver)
                        }
                    }
                }
            }
        }
        if let move {
            if move.column {
                let column = grid.map { $0[move.index] }
                for r in 0..<rows { grid[(r + move.step + rows) % rows][move.index] = column[r] }
            } else {
                let row = grid[move.index]
                for c in 0..<columns { grid[move.index][(c + move.step + columns) % columns] = row[c] }
            }
        }
    }
    return frames
}

// Packs frames into an animated WebP that loops forever
func animate(_ frames: [NSBitmapImageRep], to file: String) {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    var args = ["img2webp", "-loop", "0", "-lossless", "-d", String(Int(1000 / fps))]
    for (i, frame) in frames.enumerated() {
        let path = dir.appendingPathComponent(String(format: "%04d.png", i)).path
        write(frame, to: path)
        args.append(path)
    }
    args += ["-o", file]
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = args
    process.standardOutput = FileHandle.nullDevice
    try! process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { fatalError("img2webp failed for \(file)") }
}

for (app, name, tile, ink, motion) in agents {
    guard let source = rex.image(forResource: name) else { fatalError("no \(name) in Rex") }
    let glyph = tint(source, ink)
    let frames: [() -> Void]
    switch motion {
    case .turn: frames = turnFrames(glyph)
    case let .slide(columns, rows, moves):
        frames = slideFrames(glyph, ink: ink, columns: columns, rows: rows, moves: moves)
    }
    // The animation's first frame is the glyph at rest
    let still = frames[0]
    write(icon(tile: tile, border: nil, paint: still), to: "\(out)/\(app).png")
    for (state, color) in states {
        let icons: [NSBitmapImageRep]
        let color = rgb(color)
        switch state {
        case "working":
            // A dim ring with a bright arc that fades over the half turn
            // behind its head, the head going clockwise from the top, whole
            // laps in the glyph's loop
            let laps = max(1, (Double(frames.count) / fps / lap).rounded())
            icons = frames.enumerated().map { i, paint in
                let head = .pi / 2 - 2 * .pi * laps * Double(i) / Double(frames.count)
                return icon(tile: tile, border: around { angle in
                    color.withAlphaComponent(0.3 + 0.7 * max(0, 1 - 2 * turns(head, angle)))
                }, paint: paint)
            }
        case "unread":
            // A rest on the ring, then a soft band of light that glides
            // across it diagonally, top left to bottom right, easing in and out
            let resting = Int(rest * fps), count = resting + Int(sweep * fps)
            let light = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                   colors: [NSColor.white.withAlphaComponent(0).cgColor,
                                            NSColor.white.withAlphaComponent(0.7).cgColor,
                                            NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                                   locations: [0, 0.5, 1])!
            icons = (0..<count).map { i in
                icon(tile: tile, border: { cg in
                    cg.setFillColor(color.cgColor)
                    cg.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))
                    guard i >= resting else { return }
                    // The band's middle, along the diagonal from past the top
                    // left corner (-) to past the bottom right (+)
                    let t = Double(i - resting) / (sweep * fps)
                    let along = -0.2 + 1.4 * (1 - cos(.pi * t)) / 2
                    let middle = CGPoint(x: along * pixels, y: pixels - along * pixels)
                    let half = pixels * 0.2 / 2.squareRoot()
                    cg.drawLinearGradient(light, start: CGPoint(x: middle.x - half, y: middle.y + half),
                                          end: CGPoint(x: middle.x + half, y: middle.y - half), options: [])
                }, paint: still)
            }
        default:
            let count = Int(breath * fps)
            icons = (0..<count).map { i in
                let strength = 0.65 + 0.35 * cos(2 * .pi * Double(i) / Double(count))
                return icon(tile: tile, border: around { _ in color.withAlphaComponent(strength) }, paint: still)
            }
        }
        animate(icons, to: "\(out)/\(app)-\(state).webp")
    }
}
