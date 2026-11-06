import CoreGraphics
import Testing

@testable import NotchVeilCore

@Test func shapeRespectsNonzeroBoundsOrigin() {
    let bounds = CGRect(x: 100, y: -50, width: 1440, height: 50)
    let path = NotchVeilShapeCalculator.path(in: bounds, underlap: 16)
    #expect(path.boundingBoxOfPath == bounds)
    #expect(path.contains(CGPoint(x: bounds.midX, y: bounds.minY + 8)) == false)
    #expect(path.contains(CGPoint(x: bounds.midX, y: bounds.minY + 25)))
    #expect(path.contains(CGPoint(x: bounds.minX + 0.5, y: bounds.minY + 8)))
}

@Test func ignoresScreensWithoutANotch() {
    let metrics = NotchVeilScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        safeAreaTop: 0,
        auxiliaryTopLeft: .zero,
        auxiliaryTopRight: .zero,
        backingScaleFactor: 2
    )

    #expect(NotchVeilGeometryCalculator.geometry(for: metrics) == nil)
}

@Test func alignsThePanelToPhysicalPixels() throws {
    let metrics = NotchVeilScreenMetrics(
        frame: CGRect(x: 0.25, y: 0, width: 1440.5, height: 932.25),
        safeAreaTop: 37.25,
        auxiliaryTopLeft: CGRect(x: 0, y: 895, width: 600, height: 37.25),
        auxiliaryTopRight: CGRect(x: 840, y: 895, width: 600, height: 37.25),
        backingScaleFactor: 2
    )

    let geometry = try #require(NotchVeilGeometryCalculator.geometry(for: metrics))
    #expect(geometry.notchHeight == 37.5)
    #expect((geometry.panelFrame.minY * 2).rounded() == geometry.panelFrame.minY * 2)
    #expect((geometry.panelFrame.maxY * 2).rounded() == geometry.panelFrame.maxY * 2)
}

@Test func auxiliaryAreaCanProvideTheNotchHeight() throws {
    let metrics = NotchVeilScreenMetrics(
        frame: CGRect(x: -1440, y: 0, width: 1440, height: 932),
        safeAreaTop: 32,
        auxiliaryTopLeft: CGRect(x: -1440, y: 894, width: 620, height: 38),
        auxiliaryTopRight: CGRect(x: -620, y: 894, width: 620, height: 38),
        backingScaleFactor: 2
    )

    let geometry = try #require(NotchVeilGeometryCalculator.geometry(for: metrics))
    #expect(geometry.notchHeight == 38)
    #expect(geometry.panelFrame.maxY == metrics.frame.maxY)
}

@Test func shapeKeepsTheCenterUnderlapTransparent() {
    let bounds = CGRect(x: 0, y: 0, width: 1_710, height: 49)
    let path = NotchVeilShapeCalculator.path(in: bounds, underlap: 15.5)

    #expect(path.contains(CGPoint(x: bounds.midX, y: 8)) == false)
    #expect(path.contains(CGPoint(x: bounds.midX, y: 16)) == true)
    #expect(path.contains(CGPoint(x: 0.5, y: 8)) == true)
    #expect(path.contains(CGPoint(x: bounds.maxX - 0.5, y: 8)) == true)
}
