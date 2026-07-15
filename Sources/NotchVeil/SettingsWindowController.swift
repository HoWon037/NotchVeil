import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let closeAction: () -> Void

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
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        closeAction()
    }
}
