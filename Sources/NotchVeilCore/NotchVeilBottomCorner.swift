import CoreGraphics

public enum NotchVeilBottomCorner: CaseIterable, Hashable {
    case left, right

    /// Keep each window confined to its corner, on the display's pixel grid.
    public func panelFrame(in screenFrame: CGRect, backingScaleFactor scale: CGFloat) -> CGRect? {
        guard scale.isFinite, scale > 0, !screenFrame.isEmpty, !screenFrame.isInfinite else {
            return nil
        }

        let left = (screenFrame.minX * scale).rounded() / scale
        let right = (screenFrame.maxX * scale).rounded() / scale
        let bottom = (screenFrame.minY * scale).rounded() / scale
        let top = (screenFrame.maxY * scale).rounded() / scale
        let radius: CGFloat = 28
        let size = (min(radius, (right - left) / 2, top - bottom) * scale).rounded(.down) / scale
        guard size > 0 else { return nil }

        return CGRect(x: self == .left ? left : right - size, y: bottom, width: size, height: size)
    }

    /// Draw just the wedge outside the curve. A window in front of it clips the
    /// overlap with its own corner mask when it reaches the display edge.
    public func path(in bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        guard !bounds.isEmpty else { return path }

        let outerX = self == .left ? bounds.minX : bounds.maxX
        let innerX = self == .left ? bounds.maxX : bounds.minX
        let kappa: CGFloat = 0.552_284_749_8
        path.move(to: CGPoint(x: outerX, y: bounds.minY))
        path.addLine(to: CGPoint(x: innerX, y: bounds.minY))
        path.addCurve(
            to: CGPoint(x: outerX, y: bounds.maxY),
            control1: CGPoint(x: innerX + (outerX - innerX) * kappa, y: bounds.minY),
            control2: CGPoint(x: outerX, y: bounds.maxY - bounds.height * kappa)
        )
        path.closeSubpath()
        return path
    }
}
