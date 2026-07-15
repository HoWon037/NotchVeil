import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: make-app-icon.swift <source.png> <output.png>\n", stderr)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let source = NSImage(contentsOf: sourceURL),
      let representation = source.representations.first else {
    fputs("unable to read source image\n", stderr)
    exit(1)
}

let sourceSize = NSSize(width: representation.pixelsWide, height: representation.pixelsHigh)
let cropSide = min(sourceSize.width, sourceSize.height) * 0.895
let cropRect = NSRect(
    x: (sourceSize.width - cropSide) / 2,
    y: (sourceSize.height - cropSide) / 2,
    width: cropSide,
    height: cropSide
)
let outputSize = NSSize(width: 1024, height: 1024)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("unable to create output bitmap\n", stderr)
    exit(1)
}

bitmap.size = outputSize
NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("unable to create graphics context\n", stderr)
    exit(1)
}
NSGraphicsContext.current = context
context.imageInterpolation = .high
NSColor.clear.setFill()
NSRect(origin: .zero, size: outputSize).fill()

let clip = NSBezierPath(roundedRect: NSRect(origin: .zero, size: outputSize), xRadius: 205, yRadius: 205)
clip.addClip()
source.draw(
    in: NSRect(origin: .zero, size: outputSize),
    from: cropRect,
    operation: .copy,
    fraction: 1,
    respectFlipped: true,
    hints: [.interpolation: NSImageInterpolation.high]
)
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("unable to encode PNG\n", stderr)
    exit(1)
}

try png.write(to: outputURL, options: .atomic)
