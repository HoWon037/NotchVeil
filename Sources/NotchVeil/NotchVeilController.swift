import AppKit
import NotchVeilCore
import ServiceManagement

@MainActor
final class NotchVeilController: NSObject, NSApplicationDelegate {
    private var panelsByScreenNumber: [NSNumber: NotchVeilPanel] = [:]
    private var defaultCenterObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private let settings = AppSettings()
    private var settingsWindowController: SettingsWindowController?
    private var statusItem: NSStatusItem?
    private var statusToggleItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("NotchVeil maintains the notch background")
        NSApp.setActivationPolicy(.accessory)
        connectSettings()
        settings.reportStaleLoginItemRegistration()
        installObservers()
        rebuildPanels()
        updateStatusItemVisibility()

        let launchedAtLogin = ProcessInfo.processInfo.arguments.contains("--launch-at-login")
        if !launchedAtLogin {
            showSettingsWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hidePanels()
        removeStatusItem()
        ProcessInfo.processInfo.enableAutomaticTermination("NotchVeil maintains the notch background")
        removeObservers()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showSettingsWindow()
        return false
    }

    private func connectSettings() {
        settings.onLanguageChange = { [weak self] in
            guard let self else { return }
            if let statusItem {
                statusItem.menu = makeStatusMenu()
                updateStatusToggleItem()
            }
            settingsWindowController?.updateTitle(settings.text(.settings))
        }
        settings.onEnabledChange = { [weak self] enabled in
            guard let self else { return }
            if enabled {
                rebuildPanels()
            } else {
                hidePanels()
            }
            updateStatusToggleItem()
        }

        settings.onMenuBarIconChange = { [weak self] _ in
            self?.updateStatusItemVisibility()
        }

        settings.onLoginItemError = { [weak self] message in
            self?.showLoginItemError(message)
        }

        settings.onLoginItemRequiresApproval = { [weak self] in
            self?.showLoginItemApprovalAlert()
        }
    }

    private func installObservers() {
        defaultCenterObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuildPanels() }
            }
        )

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let workspaceNotifications: [Notification.Name] = [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
            NSWorkspace.activeSpaceDidChangeNotification,
        ]

        for name in workspaceNotifications {
            workspaceObservers.append(
                workspaceCenter.addObserver(
                    forName: name,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated { self?.rebuildPanels() }
                }
            )
        }

        let hideNotifications: [Notification.Name] = [
            NSWorkspace.willSleepNotification,
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification,
        ]

        for name in hideNotifications {
            workspaceObservers.append(
                workspaceCenter.addObserver(
                    forName: name,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated { self?.hidePanels() }
                }
            )
        }
    }

    private func removeObservers() {
        defaultCenterObservers.forEach(NotificationCenter.default.removeObserver)
        defaultCenterObservers.removeAll()
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceObservers.removeAll()
    }

    private func rebuildPanels() {
        guard settings.isEnabled else {
            hidePanels()
            return
        }

        var activeScreenNumbers = Set<NSNumber>()

        for screen in NSScreen.screens {
            guard let screenNumber = screen.deviceDescription[.init("NSScreenNumber")] as? NSNumber else {
                continue
            }

            let metrics = NotchVeilScreenMetrics(
                frame: screen.frame,
                safeAreaTop: screen.safeAreaInsets.top,
                auxiliaryTopLeft: screen.auxiliaryTopLeftArea ?? .zero,
                auxiliaryTopRight: screen.auxiliaryTopRightArea ?? .zero,
                backingScaleFactor: screen.backingScaleFactor
            )

            guard let geometry = NotchVeilGeometryCalculator.geometry(for: metrics) else {
                panelsByScreenNumber.removeValue(forKey: screenNumber)?.orderOut(nil)
                continue
            }

            activeScreenNumbers.insert(screenNumber)
            let panel: NotchVeilPanel
            if let existingPanel = panelsByScreenNumber[screenNumber] {
                existingPanel.updateGeometry(geometry)
                panel = existingPanel
            } else {
                panel = NotchVeilPanel(geometry: geometry)
                panelsByScreenNumber[screenNumber] = panel
            }
            panel.orderFrontRegardless()
        }

        for screenNumber in Set(panelsByScreenNumber.keys).subtracting(activeScreenNumbers) {
            panelsByScreenNumber.removeValue(forKey: screenNumber)?.orderOut(nil)
        }
    }

    private func hidePanels() {
        for panel in panelsByScreenNumber.values {
            panel.orderOut(nil)
        }
    }

    private func showSettingsWindow() {
        NSApp.setActivationPolicy(.regular)

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                settings: settings,
                quitAction: { NSApp.terminate(nil) },
                closeAction: { [weak self] in
                    self?.settingsWindowDidClose()
                }
            )
        }

        settings.refreshLaunchAtLoginState()
        settingsWindowController?.present()
    }

    private func settingsWindowDidClose() {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                settingsWindowController?.window?.isVisible == false
            else {
                return
            }
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func updateStatusItemVisibility() {
        if settings.showsMenuBarIcon {
            installStatusItemIfNeeded()
        } else {
            removeStatusItem()
        }
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else {
            updateStatusToggleItem()
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image =
            NSImage(
                systemSymbolName: "rectangle.tophalf.inset.filled",
                accessibilityDescription: "NotchVeil"
            )
            ?? NSImage(
                systemSymbolName: "rectangle",
                accessibilityDescription: "NotchVeil"
            )
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = "NotchVeil"

        item.menu = makeStatusMenu()
        statusItem = item
        updateStatusToggleItem()
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        let openItem = NSMenuItem(
            title: settings.text(.openSettings),
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        let toggleItem = NSMenuItem(
            title: "",
            action: #selector(toggleNotchVeilFromMenu),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        statusToggleItem = toggleItem

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: settings.text(.quit),
            action: #selector(quitFromMenu),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func removeStatusItem() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
        statusToggleItem = nil
    }

    private func updateStatusToggleItem() {
        statusToggleItem?.title = settings.text(settings.isEnabled ? .turnOff : .turnOn)
    }

    @objc private func openSettingsFromMenu() {
        showSettingsWindow()
    }

    @objc private func toggleNotchVeilFromMenu() {
        settings.setEnabled(!settings.isEnabled)
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func showLoginItemError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = settings.text(.loginError)
        alert.informativeText = message
        alert.addButton(withTitle: settings.text(.ok))
        alert.runModal()
    }

    private func showLoginItemApprovalAlert() {
        guard #available(macOS 13.0, *) else { return }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = settings.text(.approvalTitle)
        alert.informativeText = settings.text(.approvalDescription)
        alert.addButton(withTitle: settings.text(.openSystemSettings))
        alert.addButton(withTitle: settings.text(.later))

        if alert.runModal() == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
