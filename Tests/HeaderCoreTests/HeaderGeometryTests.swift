import CoreGraphics
import Testing
@testable import HeaderCore

@Test func ignoresScreensWithoutANotch() {
    let metrics = HeaderScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        safeAreaTop: 0,
        auxiliaryTopLeft: .zero,
        auxiliaryTopRight: .zero,
        backingScaleFactor: 2
    )

    #expect(HeaderGeometryCalculator.geometry(for: metrics) == nil)
}

@Test func alignsThePanelToPhysicalPixels() throws {
    let metrics = HeaderScreenMetrics(
        frame: CGRect(x: 0.25, y: 0, width: 1440.5, height: 932.25),
        safeAreaTop: 37.25,
        auxiliaryTopLeft: CGRect(x: 0, y: 895, width: 600, height: 37.25),
        auxiliaryTopRight: CGRect(x: 840, y: 895, width: 600, height: 37.25),
        backingScaleFactor: 2
    )

    let geometry = try #require(HeaderGeometryCalculator.geometry(for: metrics))
    #expect(geometry.notchHeight == 37.5)
    #expect((geometry.panelFrame.minY * 2).rounded() == geometry.panelFrame.minY * 2)
    #expect((geometry.panelFrame.maxY * 2).rounded() == geometry.panelFrame.maxY * 2)
}

@Test func auxiliaryAreaCanProvideTheNotchHeight() throws {
    let metrics = HeaderScreenMetrics(
        frame: CGRect(x: -1440, y: 0, width: 1440, height: 932),
        safeAreaTop: 32,
        auxiliaryTopLeft: CGRect(x: -1440, y: 894, width: 620, height: 38),
        auxiliaryTopRight: CGRect(x: -620, y: 894, width: 620, height: 38),
        backingScaleFactor: 2
    )

    let geometry = try #require(HeaderGeometryCalculator.geometry(for: metrics))
    #expect(geometry.notchHeight == 38)
    #expect(geometry.panelFrame.maxY == metrics.frame.maxY)
}

@Test func shapeKeepsTheCenterUnderlapTransparent() {
    let bounds = CGRect(x: 0, y: 0, width: 1_710, height: 49)
    let path = HeaderShapeCalculator.path(in: bounds, underlap: 15.5)

    #expect(path.contains(CGPoint(x: bounds.midX, y: 8)) == false)
    #expect(path.contains(CGPoint(x: bounds.midX, y: 16)) == true)
    #expect(path.contains(CGPoint(x: 0.5, y: 8)) == true)
    #expect(path.contains(CGPoint(x: bounds.maxX - 0.5, y: 8)) == true)
}
