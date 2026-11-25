import CoreGraphics
import Testing

@testable import NotchVeilCore

@Test func bottomPanelsTouchOnlyTheTwoDisplayCorners() throws {
    let screen = CGRect(x: -1512, y: -982, width: 1512, height: 982)
    let left = try #require(NotchVeilBottomCorner.left.panelFrame(in: screen, backingScaleFactor: 2))
    let right = try #require(NotchVeilBottomCorner.right.panelFrame(in: screen, backingScaleFactor: 2))

    #expect(left.origin == screen.origin)
    #expect(right.maxX == screen.maxX)
    #expect(right.minY == screen.minY)
    #expect(left.size == right.size)
    #expect(left.width == left.height)
    #expect(left.width < 40)
    #expect(!left.intersects(right))
    #expect(!left.contains(CGPoint(x: screen.midX, y: screen.minY + 1)))
    #expect(!right.contains(CGPoint(x: screen.midX, y: screen.minY + 1)))
}

@Test func bottomPanelsSnapToTheBackingPixelGrid() throws {
    let screen = CGRect(x: -300.25, y: -0.25, width: 600, height: 400)
    for scale: CGFloat in [1, 1.25, 2, 3] {
        for corner in NotchVeilBottomCorner.allCases {
            let frame = try #require(corner.panelFrame(in: screen, backingScaleFactor: scale))
            for coordinate in [frame.minX, frame.minY, frame.maxX, frame.maxY] {
                #expect(abs(coordinate * scale - (coordinate * scale).rounded()) < 0.000_001)
            }
        }
    }
}

@Test func bottomCornerPanelsDoNotOverlapOnSmallFrames() throws {
    let screen = CGRect(x: 0, y: 0, width: 12, height: 4)
    let left = try #require(NotchVeilBottomCorner.left.panelFrame(in: screen, backingScaleFactor: 2))
    let right = try #require(NotchVeilBottomCorner.right.panelFrame(in: screen, backingScaleFactor: 2))

    #expect(screen.contains(left))
    #expect(screen.contains(right))
    #expect(!left.intersects(right))
    #expect(NotchVeilBottomCorner.left.panelFrame(in: .zero, backingScaleFactor: 2) == nil)
    #expect(NotchVeilBottomCorner.left.panelFrame(in: screen, backingScaleFactor: .infinity) == nil)
}

@Test func bottomCornerPathsMirrorEachOtherAndLeaveTheInteriorClear() {
    let bounds = CGRect(x: 120, y: -30, width: 28, height: 28)
    let left = NotchVeilBottomCorner.left.path(in: bounds)
    let right = NotchVeilBottomCorner.right.path(in: bounds)

    #expect(left.boundingBoxOfPath == bounds)
    #expect(right.boundingBoxOfPath == bounds)
    #expect(left.contains(CGPoint(x: bounds.minX + 1, y: bounds.minY + 1)))
    #expect(right.contains(CGPoint(x: bounds.maxX - 1, y: bounds.minY + 1)))
    #expect(!left.contains(CGPoint(x: bounds.midX, y: bounds.midY)))
    #expect(!right.contains(CGPoint(x: bounds.midX, y: bounds.midY)))

    for x in 0..<28 {
        for y in 0..<28 {
            let offset = CGFloat(x) + 0.5
            let row = bounds.minY + CGFloat(y) + 0.5
            #expect(
                left.contains(CGPoint(x: bounds.minX + offset, y: row))
                    == right.contains(CGPoint(x: bounds.maxX - offset, y: row))
            )
        }
    }
}
