import AppKit

guard let out = CommandLine.arguments.dropFirst().first else {
    FileHandle.standardError.write(Data("Usage: swift make-icons.swift <output-directory>\n".utf8))
    exit(64)
}
let rex = Bundle(path: "/Applications/Rex Beta.app/Contents/Resources/SuperBlockIcons_SuperBlockIcons.bundle")!
let pixels = 64.0
// As Flare's row.rs draws a tile, its corners round by 24% of it and its
// glyph fills 60%, but it fills 80% of the icon (not 84%), leaving room
// round it for a border
let tileShare = 0.8, radiusShare = 0.24, glyphShare = 0.6
let borderWidth = 5.0, borderGap = 1.2
let fps = 30.0, breath = 4.0, lap = 1.5, sweep = 1.4, rest = 2.0

func rgb(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let states: [(String, Int)] = [
    ("blocked", 0xFF3B30), ("error", 0xAF52DE), ("unread", 0x30B0C7), ("working", 0xFF9500),
]

struct Move {
    let column: Bool, index: Int, step: Int
    var undo: Move { Move(column: column, index: index, step: -step) }
}

enum Motion {
    case turn
    case slide(columns: Int, rows: Int, moves: [Move])
}

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

func centered(_ image: NSImage) -> NSRect {
    NSRect(x: (pixels - image.size.width) / 2, y: (pixels - image.size.height) / 2,
           width: image.size.width, height: image.size.height)
}

// AppKit uses different glyph bitmaps at small sizes, so sample a large render.
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

typealias Border = (CGContext) -> Void

func angularBorder(_ colorAtCounterclockwiseRadians: @escaping (Double) -> NSColor) -> Border {
    { cg in
        let wedges = 180, center = CGPoint(x: pixels / 2, y: pixels / 2)
        let overlappingWedgeWidth = 2 * Double.pi / Double(wedges) * 1.5
        cg.setBlendMode(.copy)
        for w in 0..<wedges {
            let start = 2 * .pi * Double(w) / Double(wedges)
            cg.setFillColor(colorAtCounterclockwiseRadians(start).cgColor)
            cg.move(to: center)
            cg.addArc(center: center, radius: pixels, startAngle: start, endAngle: start + overlappingWedgeWidth, clockwise: false)
            cg.closePath()
            cg.fillPath()
        }
    }
}

func turns(_ a: Double, _ b: Double) -> Double {
    let t = (b - a) / (2 * .pi)
    return t - t.rounded(.down)
}

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

func turnFrames(_ glyph: NSImage) -> [() -> Void] {
    let count = Int(3 * fps)
    return (0..<count).map { i in
        let t = Double(i) / Double(count)
        return { turned(glyph, turn: t, scale: 0.95 + 0.05 * cos(2 * .pi * t)) }
    }
}

func slideFrames(_ glyph: NSImage, ink: Int, columns: Int, rows: Int, moves: [Move]) -> [() -> Void] {
    var steps: [(Move?, Double)] = [(nil, 0.9)]
    for move in moves { steps += [(move, 0.4), (nil, 0.1)] }
    steps.append((nil, 0.2))
    for move in moves.reversed() { steps += [(move.undo, 0.4), (nil, 0.1)] }
    let cell = 6
    let shares = sampled(glyph, columns: columns, rows: rows)
    let box = NSRect(x: (Int(pixels) - cell * columns) / 2, y: (Int(pixels) - cell * rows) / 2,
                     width: cell * columns, height: cell * rows)
    var grid = (0..<rows).map { r in (0..<columns).map { c in (r, c) } }
    var frames: [() -> Void] = []
    for (move, seconds) in steps {
        let count = Int((seconds * fps).rounded())
        for i in 0..<count {
            let shift = move.map { Int((ease(Double(i) / Double(count)) * Double(cell)).rounded()) * $0.step } ?? 0
            let cells = grid
            frames.append {
                NSBezierPath(rect: box).addClip()
                for r in 0..<rows {
                    for c in 0..<columns {
                        let (sr, sc) = cells[r][c]
                        var x = Int(box.minX) + c * cell, y = Int(box.minY) + (rows - 1 - r) * cell
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
    let still = frames[0]
    write(icon(tile: tile, border: nil, paint: still), to: "\(out)/\(app).png")
    for (state, color) in states {
        let icons: [NSBitmapImageRep]
        let color = rgb(color)
        switch state {
        case "working":
            let laps = max(1, (Double(frames.count) / fps / lap).rounded())
            icons = frames.enumerated().map { i, paint in
                let head = .pi / 2 - 2 * .pi * laps * Double(i) / Double(frames.count)
                return icon(tile: tile, border: angularBorder { angle in
                    color.withAlphaComponent(0.3 + 0.7 * max(0, 1 - 2 * turns(head, angle)))
                }, paint: paint)
            }
        case "unread":
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
                return icon(tile: tile, border: angularBorder { _ in color.withAlphaComponent(strength) }, paint: still)
            }
        }
        animate(icons, to: "\(out)/\(app)-\(state).webp")
    }
}
