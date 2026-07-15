import CoreGraphics
import Foundation

public struct HeaderScreenMetrics {
    public var frame: CGRect
    public var safeAreaTop: CGFloat
    public var auxiliaryTopLeft: CGRect
    public var auxiliaryTopRight: CGRect
    public var backingScaleFactor: CGFloat

    public init(
        frame: CGRect,
        safeAreaTop: CGFloat,
        auxiliaryTopLeft: CGRect,
        auxiliaryTopRight: CGRect,
        backingScaleFactor: CGFloat
    ) {
        self.frame = frame
        self.safeAreaTop = safeAreaTop
        self.auxiliaryTopLeft = auxiliaryTopLeft
        self.auxiliaryTopRight = auxiliaryTopRight
        self.backingScaleFactor = backingScaleFactor
    }
}

public struct HeaderGeometry {
    public var panelFrame: CGRect
    public var notchHeight: CGFloat
    public var underlap: CGFloat

    public init(panelFrame: CGRect, notchHeight: CGFloat, underlap: CGFloat) {
        self.panelFrame = panelFrame
        self.notchHeight = notchHeight
        self.underlap = underlap
    }
}

public enum HeaderGeometryCalculator {
    /// Returns nil for displays without a top safe-area inset. The panel extends
    /// slightly behind normal app windows so their own corner mask defines the
    /// visible curve without inspecting or modifying another app.
    public static func geometry(for metrics: HeaderScreenMetrics) -> HeaderGeometry? {
        let auxiliaryHeight = max(
            metrics.auxiliaryTopLeft.height,
            metrics.auxiliaryTopRight.height
        )
        let rawNotchHeight = max(metrics.safeAreaTop, auxiliaryHeight)
        guard rawNotchHeight > 0 else { return nil }

        let scale = max(metrics.backingScaleFactor, 1)
        let notchHeight = ceil(rawNotchHeight * scale) / scale
        let rawUnderlap = min(20, max(12, notchHeight * 0.45))
        let underlap = ceil(rawUnderlap * scale) / scale

        let top = round(metrics.frame.maxY * scale) / scale
        let bottom = floor((top - notchHeight - underlap) * scale) / scale
        let left = round(metrics.frame.minX * scale) / scale
        let right = round(metrics.frame.maxX * scale) / scale

        return HeaderGeometry(
            panelFrame: CGRect(
                x: left,
                y: bottom,
                width: right - left,
                height: top - bottom
            ),
            notchHeight: notchHeight,
            underlap: underlap
        )
    }
}

public enum HeaderShapeCalculator {
    /// Creates a full-width notch-height band with only two curved corner
    /// wedges extending into the underlap. The transparent center prevents the
    /// underlap from appearing as a straight bar on the desktop.
    public static func path(in bounds: CGRect, underlap: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let width = bounds.width
        let height = bounds.height
        let radius = min(max(underlap, 0), height, width / 2)

        guard width > 0, height > 0 else { return path }
        guard radius > 0 else {
            path.addRect(bounds)
            return path
        }

        // Cubic approximation of a quarter circle. The curve is only the
        // background outside an app's top corners; the app remains the final
        // mask when it is maximized.
        let kappa: CGFloat = 0.552_284_749_8
        let control = radius * kappa

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: width, y: 0))
        path.addCurve(
            to: CGPoint(x: width - radius, y: radius),
            control1: CGPoint(x: width, y: control),
            control2: CGPoint(x: width - radius + control, y: radius)
        )
        path.addLine(to: CGPoint(x: radius, y: radius))
        path.addCurve(
            to: CGPoint(x: 0, y: 0),
            control1: CGPoint(x: radius - control, y: radius),
            control2: CGPoint(x: 0, y: control)
        )
        path.closeSubpath()
        return path
    }
}
