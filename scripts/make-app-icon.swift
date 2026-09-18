// Draws the NotchVeil app icon and writes AppIcon-1024.png plus AppIcon.icns.
//
//   swift scripts/make-app-icon.swift Resources
//
// The subject is the machine itself: a MacBook display seen head on, with the
// notch cut into the top of the screen. Drawing a real object rather than an
// abstract band is what keeps it from looking like a generated placeholder.
//
// Everything is flat. No gradients, no baked container, no rim highlight, no
// drop shadow -- macOS 26+ composites its own, and faking them is what made the
// previous icon read as cheap. The artwork is procedural, so every icns slice is
// rendered natively at its own pixel size instead of downsampled from 1024.

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: make-app-icon.swift <output-directory>\n", stderr)
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

// MARK: - Palette

func hex(_ value: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: 1
    )
}

/// Near-black for the bezel and the notch, because that is what the app paints
/// on screen. Warm off-white for the display: pure white loses its edge on a
/// light Dock.
let bezelColor = hex(0x0A0A0B)
let screenColor = hex(0xF2EEE6)

// MARK: - Geometry

/// Continuous-curvature corner. `NSBezierPath(roundedRect:)` draws a circular
/// arc, which reads as a visible kink next to real macOS icons.
func squirclePath(in rect: CGRect, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let control = radius * 0.30
    let (x, y, w, h) = (rect.minX, rect.minY, rect.width, rect.height)

    path.move(to: CGPoint(x: x + radius, y: y))
    path.addLine(to: CGPoint(x: x + w - radius, y: y))
    path.addCurve(
        to: CGPoint(x: x + w, y: y + radius),
        control1: CGPoint(x: x + w - control, y: y),
        control2: CGPoint(x: x + w, y: y + control)
    )
    path.addLine(to: CGPoint(x: x + w, y: y + h - radius))
    path.addCurve(
        to: CGPoint(x: x + w - radius, y: y + h),
        control1: CGPoint(x: x + w, y: y + h - control),
        control2: CGPoint(x: x + w - control, y: y + h)
    )
    path.addLine(to: CGPoint(x: x + radius, y: y + h))
    path.addCurve(
        to: CGPoint(x: x, y: y + h - radius),
        control1: CGPoint(x: x + control, y: y + h),
        control2: CGPoint(x: x, y: y + h - control)
    )
    path.addLine(to: CGPoint(x: x, y: y + radius))
    path.addCurve(
        to: CGPoint(x: x + radius, y: y),
        control1: CGPoint(x: x, y: y + control),
        control2: CGPoint(x: x + control, y: y)
    )
    path.closeSubpath()
    return path
}

/// The notch, hanging from `top`. The small outward fillets where it meets the
/// top edge are what make it read as a notch rather than a slot.
func notchPath(centerX: CGFloat, top: CGFloat, width: CGFloat, depth: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let innerRadius = min(depth * 0.42, width * 0.14)
    let outerRadius = innerRadius * 0.85
    let left = centerX - width / 2
    let right = centerX + width / 2

    path.move(to: CGPoint(x: left - outerRadius, y: top))
    path.addQuadCurve(
        to: CGPoint(x: left, y: top - outerRadius),
        control: CGPoint(x: left, y: top)
    )
    path.addLine(to: CGPoint(x: left, y: top - depth + innerRadius))
    path.addQuadCurve(
        to: CGPoint(x: left + innerRadius, y: top - depth),
        control: CGPoint(x: left, y: top - depth)
    )
    path.addLine(to: CGPoint(x: right - innerRadius, y: top - depth))
    path.addQuadCurve(
        to: CGPoint(x: right, y: top - depth + innerRadius),
        control: CGPoint(x: right, y: top - depth)
    )
    path.addLine(to: CGPoint(x: right, y: top - outerRadius))
    path.addQuadCurve(
        to: CGPoint(x: right + outerRadius, y: top),
        control: CGPoint(x: right, y: top)
    )
    path.closeSubpath()
    return path
}

// MARK: - Drawing

func drawIcon(in context: CGContext, canvas: CGFloat) {
    // 824 of 1024: the macOS icon grid, so NotchVeil sits at the same optical
    // size as its neighbours in the Dock.
    let inset = canvas * (100.0 / 1024.0)
    let art = CGRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)

    context.saveGState()
    context.addPath(squirclePath(in: art, radius: art.width * 0.225))
    context.clip()

    context.setFillColor(bezelColor.cgColor)
    context.fill(art)

    let bezelWidth = art.width * 0.085
    let screen = art.insetBy(dx: bezelWidth, dy: bezelWidth)
    context.setFillColor(screenColor.cgColor)
    context.addPath(squirclePath(in: screen, radius: screen.width * 0.135))
    context.fillPath()

    // Wider and deeper than the real notch, which is the only way it survives
    // to 16pt.
    context.setFillColor(bezelColor.cgColor)
    context.addPath(
        notchPath(
            centerX: art.midX,
            top: screen.maxY,
            width: screen.width * 0.46,
            depth: screen.height * 0.20
        )
    )
    context.fillPath()

    context.restoreGState()
}

func renderPNG(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "NotchVeil", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "unable to create a \(pixels)px bitmap"
        ])
    }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }

    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "NotchVeil", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "unable to create a graphics context"
        ])
    }
    NSGraphicsContext.current = graphicsContext
    drawIcon(in: graphicsContext.cgContext, canvas: CGFloat(pixels))
    graphicsContext.flushGraphics()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "NotchVeil", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "unable to encode PNG"
        ])
    }
    return data
}

// MARK: - Output

let fileManager = FileManager.default

do {
    try renderPNG(pixels: 1024)
        .write(to: outputDirectory.appendingPathComponent("AppIcon-1024.png"), options: .atomic)

    let iconsetURL = fileManager.temporaryDirectory
        .appendingPathComponent("NotchVeil-\(UUID().uuidString).iconset")
    try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: iconsetURL) }

    for point in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let suffix = scale == 1 ? "" : "@2x"
            try renderPNG(pixels: point * scale).write(
                to: iconsetURL.appendingPathComponent("icon_\(point)x\(point)\(suffix).png"),
                options: .atomic
            )
        }
    }

    let icnsURL = outputDirectory.appendingPathComponent("AppIcon.icns")
    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
    try iconutil.run()
    iconutil.waitUntilExit()

    guard iconutil.terminationStatus == 0 else {
        fputs("iconutil failed with status \(iconutil.terminationStatus)\n", stderr)
        exit(1)
    }

    print(icnsURL.path)
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
