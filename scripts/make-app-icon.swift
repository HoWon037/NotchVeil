// Regenerate the legacy icon and native catalog artwork from the approved PNG.
// Usage: swift scripts/make-app-icon.swift <output-directory> [source-png]

import AppKit
import Foundation

func renderPNG(_ source: NSImage, pixels: Int) throws -> Data {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else {
        throw CocoaError(.fileWriteUnknown)
    }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    let canvas = CGFloat(pixels)
    let scale = min(canvas / source.size.width, canvas / source.size.height)
    let size = NSSize(width: source.size.width * scale, height: source.size.height * scale)
    source.draw(
        in: NSRect(
            x: (canvas - size.width) / 2, y: (canvas - size.height) / 2,
            width: size.width, height: size.height),
        from: .zero, operation: .copy, fraction: 1
    )
    context.flushGraphics()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return png
}

func generateIcon(output: URL, sourceURL: URL) throws {
    guard let source = NSImage(contentsOf: sourceURL),
        source.size.width > 0, source.size.height > 0
    else {
        throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: sourceURL.path])
    }
    let files = FileManager.default
    try files.createDirectory(at: output, withIntermediateDirectories: true)
    let png = try renderPNG(source, pixels: 1024)
    try png.write(to: output.appendingPathComponent("AppIcon-1024.png"), options: .atomic)

    let iconset = files.temporaryDirectory
        .appendingPathComponent("NotchVeil-\(UUID().uuidString).iconset")
    try files.createDirectory(at: iconset, withIntermediateDirectories: false)
    defer { try? files.removeItem(at: iconset) }

    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let suffix = scale == 1 ? "" : "@2x"
            try renderPNG(source, pixels: points * scale).write(
                to: iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"),
                options: .atomic
            )
        }
    }
    let converter = Process()
    converter.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    converter.arguments = [
        "-c", "icns", iconset.path, "-o", output.appendingPathComponent("AppIcon.icns").path,
    ]
    try converter.run()
    converter.waitUntilExit()
    guard converter.terminationStatus == 0 else {
        throw NSError(
            domain: "NotchVeil.IconExport", code: Int(converter.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
    }

    // The approved legacy artwork has an outer inset. Remove that inset for
    // the native catalog: macOS applies its own enclosure and padding.
    let catalog = output.appendingPathComponent("NotchVeil.icon")
    if files.fileExists(atPath: catalog.appendingPathComponent("icon.json").path) {
        guard let flattened = NSImage(data: png),
            let cgImage = flattened.cgImage(forProposedRect: nil, context: nil, hints: nil),
            let cropped = cgImage.cropping(to: CGRect(x: 120, y: 120, width: 784, height: 784))
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let artwork = NSImage(cgImage: cropped, size: NSSize(width: 784, height: 784))
        try renderPNG(artwork, pixels: 1024).write(
            to: catalog.appendingPathComponent("Assets/Artwork.png"), options: .atomic
        )
    }
}

guard (2...3).contains(CommandLine.arguments.count) else {
    fputs("usage: make-app-icon.swift <output-directory> [source-png]\n", stderr)
    exit(2)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let sourceURL =
    CommandLine.arguments.count == 3
    ? URL(fileURLWithPath: CommandLine.arguments[2])
    : output.appendingPathComponent("AppIcon-source.png")

do {
    try generateIcon(output: output, sourceURL: sourceURL)
    print(output.appendingPathComponent("AppIcon.icns").path)
} catch {
    fputs("Icon export failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
