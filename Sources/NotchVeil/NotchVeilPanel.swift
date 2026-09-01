import AppKit
import NotchVeilCore

private final class NotchVeilShapeView: NSView {
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

    /// The window sets `animationBehavior = .none`, but that does not cover the
    /// layer's implicit animations. Without this the veil visibly morphs when a
    /// display is attached or the resolution changes.
    private func updateShape() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapeLayer.frame = bounds
        shapeLayer.path = NotchVeilShapeCalculator.path(in: bounds, underlap: underlap)
        CATransaction.commit()
    }
}

final class NotchVeilPanel: NSPanel {
    private let shapeView: NotchVeilShapeView

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(geometry: NotchVeilGeometry) {
        shapeView = NotchVeilShapeView(
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

    func updateGeometry(_ geometry: NotchVeilGeometry) {
        setFrame(geometry.panelFrame, display: true, animate: false)
        shapeView.update(underlap: geometry.underlap)
    }
}
