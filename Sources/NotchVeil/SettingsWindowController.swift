import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let closeAction: () -> Void
    private var hasPositionedWindow = false

    init(
        settings: AppSettings,
        quitAction: @escaping () -> Void,
        closeAction: @escaping () -> Void
    ) {
        self.closeAction = closeAction
        let contentController = NSHostingController(
            rootView: SettingsView(settings: settings, quitAction: quitAction)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "NotchVeil"
        window.contentViewController = contentController
        window.isReleasedWhenClosed = false
        window.animationBehavior = .documentWindow
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        fitWindowToContent(window)

        if !hasPositionedWindow || !isVisibleOnAnyScreen(window) {
            center(window, on: preferredScreen(for: window))
            hasPositionedWindow = true
        }

        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        closeAction()
    }

    private func fitWindowToContent(_ window: NSWindow) {
        guard let contentView = window.contentViewController?.view else { return }
        contentView.layoutSubtreeIfNeeded()
        let fittingSize = contentView.fittingSize
        guard fittingSize.width > 0, fittingSize.height > 0 else { return }
        window.setContentSize(fittingSize)
    }

    private func preferredScreen(for window: NSWindow) -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main
            ?? window.screen
            ?? NSScreen.screens.first
    }

    private func center(_ window: NSWindow, on screen: NSScreen?) {
        guard let screen else { return }
        let visibleFrame = screen.visibleFrame
        let origin = NSPoint(
            x: (visibleFrame.midX - window.frame.width / 2).rounded(),
            y: (visibleFrame.midY - window.frame.height / 2).rounded()
        )
        window.setFrameOrigin(origin)
    }

    private func isVisibleOnAnyScreen(_ window: NSWindow) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.intersects(window.frame) }
    }
}
