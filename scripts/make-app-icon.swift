// Draws the NotchVeil app icon and writes AppIcon-1024.png plus AppIcon.icns.
//
//   swift scripts/make-app-icon.swift Resources
//
// The artwork is procedural, so every icns slice is rendered natively at its
// own pixel size instead of being downsampled from 1024.

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

/// A near-white body that still holds its silhouette on a light Dock, under a
/// true-black band. The band is #000 because that is what the app actually
/// paints on screen.
let bodyTopColor = hex(0xFBFCFD)
let bodyBottomColor = hex(0xDDE1E9)
let bandColor = NSColor.black

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

/// One of the two curved wedges the real panel extends into the underlap.
func wedgePath(in art: CGRect, bandHeight: CGFloat, radius: CGFloat, isLeft: Bool) -> CGPath {
    let path = CGMutablePath()
    let bandBottom = art.maxY - bandHeight
    let edgeX = isLeft ? art.minX : art.maxX
    let innerX = isLeft ? art.minX + radius : art.maxX - radius
    let controlX = isLeft ? art.minX + radius * 0.45 : art.maxX - radius * 0.45

    path.move(to: CGPoint(x: edgeX, y: bandBottom))
    path.addLine(to: CGPoint(x: edgeX, y: bandBottom - radius))
    path.addCurve(
        to: CGPoint(x: innerX, y: bandBottom),
        control1: CGPoint(x: edgeX, y: bandBottom - radius * 0.45),
        control2: CGPoint(x: controlX, y: bandBottom)
    )
    path.closeSubpath()
    return path
}

// MARK: - Drawing

func drawIcon(in context: CGContext, canvas: CGFloat) {
    // 824 of 1024: the classic macOS icon grid, so NotchVeil sits at the same
    // optical size as its neighbours in the Dock. No baked container shadow or
    // rim highlight -- macOS 26+ composites its own.
    let inset = canvas * (100.0 / 1024.0)
    let art = CGRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
    let body = squirclePath(in: art, radius: art.width * 0.225)

    context.saveGState()
    context.addPath(body)
    context.clip()

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [bodyTopColor.cgColor, bodyBottomColor.cgColor] as CFArray,
        locations: nil
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: art.midX, y: art.maxY),
        end: CGPoint(x: art.midX, y: art.minY),
        options: []
    )

    let bandHeight = art.height * 0.30
    context.setFillColor(bandColor.cgColor)
    context.fill(
        CGRect(x: art.minX, y: art.maxY - bandHeight, width: art.width, height: bandHeight)
    )

    let wedgeRadius = art.width * 0.11
    for isLeft in [true, false] {
        context.addPath(
            wedgePath(in: art, bandHeight: bandHeight, radius: wedgeRadius, isLeft: isLeft)
        )
        context.fillPath()
    }

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
