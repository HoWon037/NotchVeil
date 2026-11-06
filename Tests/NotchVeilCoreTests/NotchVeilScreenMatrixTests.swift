import CoreGraphics
import Testing

@testable import NotchVeilCore

// Synthetic logical-point inputs, NOT measured specifications of MacBook models.
// Sizes deliberately span compact through large displays and scaled modes.
private let screenSizes: [CGSize] = [
    CGSize(width: 1280, height: 800), CGSize(width: 1440, height: 900),
    CGSize(width: 1512, height: 982), CGSize(width: 1710, height: 1112),
    CGSize(width: 1800, height: 1169), CGSize(width: 2056, height: 1329),
]
private let notchHeights: [CGFloat] = [24, 28, 32, 37, 38, 48, 64]
private let scales: [CGFloat] = [1, 1.25, 1.5, 2, 3]
private let origins: [CGPoint] = [
    .zero, CGPoint(x: -2056, y: 0), CGPoint(x: 0, y: 1440),
    CGPoint(x: 1512, y: -1329), CGPoint(x: -1440.25, y: 100.25),
]

private func metrics(frame: CGRect, notch: CGFloat, scale: CGFloat) -> NotchVeilScreenMetrics {
    NotchVeilScreenMetrics(
        frame: frame, safeAreaTop: notch,
        auxiliaryTopLeft: .zero, auxiliaryTopRight: .zero,
        backingScaleFactor: scale
    )
}

private func isPixelAligned(_ value: CGFloat, scale: CGFloat) -> Bool {
    abs(value * scale - (value * scale).rounded()) < 0.000_001
}

@Test func syntheticScreenMatrixCoversNotchPixelsWithoutGaps() throws {
    var count = 0
    for size in screenSizes {
        for notch in notchHeights {
            for scale in scales {
                for origin in origins {
                    let frame = CGRect(origin: origin, size: size)
                    let geometry = try #require(
                        NotchVeilGeometryCalculator.geometry(
                            for: metrics(frame: frame, notch: notch, scale: scale)
                        ))
                    let context = Comment(rawValue: "frame=\(frame), notch=\(notch), scale=\(scale)")
                    let panel = geometry.panelFrame
                    #expect(panel.width > 0 && panel.height > 0, context)
                    for edge in [panel.minX, panel.maxX, panel.minY, panel.maxY] {
                        #expect(isPixelAligned(edge, scale: scale), context)
                    }
                    // Screen edges may be fractional. Snap tolerance is half a pixel.
                    #expect(abs(panel.minX - frame.minX) <= 0.5 / scale + 0.000_001, context)
                    #expect(abs(panel.maxX - frame.maxX) <= 0.5 / scale + 0.000_001, context)
                    #expect(abs(panel.maxY - frame.maxY) <= 0.5 / scale + 0.000_001, context)
                    #expect(geometry.notchHeight >= notch, context)
                    #expect(geometry.notchHeight - notch < 1 / scale + 0.000_001, context)
                    #expect(geometry.underlap >= 12 && geometry.underlap <= 20, context)

                    let path = NotchVeilShapeCalculator.path(
                        in: CGRect(origin: .zero, size: panel.size), underlap: geometry.underlap
                    )
                    // Test physical pixel centers throughout the entire notch height,
                    // at both edge columns and seven interior columns. Check the shape
                    // itself, not just the panel's bounding rectangle.
                    // A center exactly on a synthetic screen/shape boundary has
                    // no unambiguous inside/outside classification. Exclude only
                    // those boundary centers, not any strictly interior pixels.
                    let epsilon: CGFloat = 0.000_001
                    let firstX = (frame.minX * scale - 0.5 + epsilon).rounded(.up)
                    let lastX = (frame.maxX * scale - 0.5 - epsilon).rounded(.down)
                    let firstY = ((frame.maxY - notch) * scale - 0.5 + epsilon).rounded(.up)
                    let lastY = (frame.maxY * scale - 0.5 - epsilon).rounded(.down)
                    var bandCovered = true
                    for column in 0...8 {
                        let pixelX = firstX + ((lastX - firstX) * CGFloat(column) / 8).rounded()
                        for pixelY in Int(firstY)...Int(lastY) {
                            let point = CGPoint(
                                x: (pixelX + 0.5) / scale - panel.minX,
                                y: (CGFloat(pixelY) + 0.5) / scale - panel.minY
                            )
                            if !path.contains(point) { bandCovered = false }
                        }
                    }
                    #expect(bandCovered, context)
                    // The underlap must not become an extra full-width desktop stripe.
                    for fraction: CGFloat in [0.2, 0.5, 0.8] {
                        let y = geometry.underlap * fraction
                        #expect(!path.contains(CGPoint(x: panel.width / 2, y: y)), context)
                        #expect(path.contains(CGPoint(x: 0.1 / scale, y: y)), context)
                        #expect(path.contains(CGPoint(x: panel.width - 0.1 / scale, y: y)), context)
                    }
                    count += 1
                }
            }
        }
    }
    #expect(count == 1050)
}

@Test func syntheticNotchlessDisplaysProduceNoPanel() {
    for size in screenSizes {
        for scale in scales {
            for origin in origins {
                #expect(
                    NotchVeilGeometryCalculator.geometry(
                        for: metrics(
                            frame: CGRect(origin: origin, size: size), notch: 0, scale: scale
                        )) == nil)
            }
        }
    }
}

@Test func eitherAuxiliaryAreaCanSupplyMissingOrLargerSafeInset() throws {
    for heights: [CGFloat] in [[0, 38, 0], [0, 0, 38], [32, 38, 37], [38, 32, 32]] {
        var input = metrics(
            frame: CGRect(x: -1512, y: 982, width: 1512, height: 982),
            notch: heights[0], scale: 2)
        input.auxiliaryTopLeft = CGRect(x: -1512, y: 1926, width: 600, height: heights[1])
        input.auxiliaryTopRight = CGRect(x: -600, y: 1926, width: 600, height: heights[2])
        let geometry = try #require(NotchVeilGeometryCalculator.geometry(for: input))
        #expect(geometry.notchHeight == 38)
    }
}

@Test func samePhysicalNotchKeepsItsCoverageAcrossLogicalScaleChanges() throws {
    for scale: CGFloat in [1, 1.25, 1.5, 2, 2.5, 3] {
        let geometry = try #require(
            NotchVeilGeometryCalculator.geometry(
                for: metrics(
                    frame: CGRect(x: 0, y: 0, width: 3024 / scale, height: 1964 / scale),
                    notch: 74 / scale, scale: scale
                )))
        #expect(abs(geometry.panelFrame.width * scale - 3024) < 0.000_001)
        #expect(abs(geometry.panelFrame.maxY * scale - 1964) < 0.000_001)
        #expect(abs(geometry.notchHeight * scale - 74) < 0.000_001)
    }
}
