import AppKit
import HeaderCore

private final class HeaderShapeView: NSView {
    private let shapeLayer = CAShapeLayer()
    private var underlap: CGFloat

    init(frame: NSRect, underlap: CGFloat) {
        self.underlap = underlap
        super.init(frame: frame)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        shapeLayer.fillColor = NSColor.black.cgColor
        shapeLayer.allowsEdgeAntialiasing = true
        layer?.addSublayer(shapeLayer)
        updateShape()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateShape()
    }

    func update(underlap: CGFloat) {
        self.underlap = underlap
        updateShape()
    }

    private func updateShape() {
        shapeLayer.frame = bounds
        shapeLayer.path = HeaderShapeCalculator.path(in: bounds, underlap: underlap)
    }
}

final class HeaderPanel: NSPanel {
    private let shapeView: HeaderShapeView

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(geometry: HeaderGeometry) {
        shapeView = HeaderShapeView(
            frame: NSRect(origin: .zero, size: geometry.panelFrame.size),
            underlap: geometry.underlap
        )
        super.init(
            contentRect: geometry.panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        backgroundColor = .clear
        colorSpace = .sRGB
        isOpaque = false
        alphaValue = 1
        hasShadow = false
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]

        shapeView.autoresizingMask = [.width, .height]
        contentView = shapeView
    }

    func updateGeometry(_ geometry: HeaderGeometry) {
        setFrame(geometry.panelFrame, display: true, animate: false)
        shapeView.update(underlap: geometry.underlap)
    }
}
