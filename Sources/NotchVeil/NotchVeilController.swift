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
        settings.reconcileLoginItemRegistration()
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
            NSWorkspace.activeSpaceDidChangeNotification
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
            NSWorkspace.sessionDidResignActiveNotification
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
            let panel = panelsByScreenNumber[screenNumber] ?? NotchVeilPanel(geometry: geometry)
            panel.updateGeometry(geometry)
            panel.orderFrontRegardless()
            panelsByScreenNumber[screenNumber] = panel

            NSLog(
                "NotchVeil screen=%@ safeTop=%.2f notchHeight=%.2f underlap=%.2f frame=%@",
                screenNumber,
                metrics.safeAreaTop,
                geometry.notchHeight,
                geometry.underlap,
                NSStringFromRect(geometry.panelFrame)
            )
        }

        for screenNumber in Set(panelsByScreenNumber.keys).subtracting(activeScreenNumbers) {
            panelsByScreenNumber.removeValue(forKey: screenNumber)?.orderOut(nil)
        }
    }

    private func hidePanels() {
        panelsByScreenNumber.values.forEach { $0.orderOut(nil) }
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
                  settingsWindowController?.window?.isVisible == false else {
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
        let image = NSImage(
            systemSymbolName: "rectangle.tophalf.inset.filled",
            accessibilityDescription: "NotchVeil"
        ) ?? NSImage(
            systemSymbolName: "rectangle",
            accessibilityDescription: "NotchVeil"
        )
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = "NotchVeil"

        let menu = NSMenu()
        let openItem = NSMenuItem(
            title: "설정 열기",
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
            title: "앱 종료",
            action: #selector(quitFromMenu),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
        updateStatusToggleItem()
    }

    private func removeStatusItem() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
        statusToggleItem = nil
    }

    private func updateStatusToggleItem() {
        statusToggleItem?.title = settings.isEnabled ? "노치 가리기 끄기" : "노치 가리기 켜기"
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
        alert.messageText = "자동 실행을 변경할 수 없습니다"
        alert.informativeText = message
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }

    private func showLoginItemApprovalAlert() {
        guard #available(macOS 13.0, *) else { return }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "로그인 항목 허용이 필요합니다"
        alert.informativeText = "시스템 설정의 로그인 항목에서 NotchVeil을 허용해 주세요."
        alert.addButton(withTitle: "시스템 설정 열기")
        alert.addButton(withTitle: "나중에")

        if alert.runModal() == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
