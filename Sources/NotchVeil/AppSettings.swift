import Combine
import Foundation
import NotchVeilCore
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    private typealias Key = NotchVeilDefaultsKey

    @Published private(set) var isEnabled: Bool
    @Published private(set) var launchesAtLogin: Bool
    @Published private(set) var showsMenuBarIcon: Bool

    var onEnabledChange: ((Bool) -> Void)?
    var onMenuBarIconChange: ((Bool) -> Void)?
    var onLoginItemError: ((String) -> Void)?
    var onLoginItemRequiresApproval: (() -> Void)?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        NotchVeilDefaultsMigrator.migrate(defaults)

        if defaults.object(forKey: Key.isEnabled) == nil {
            defaults.set(true, forKey: Key.isEnabled)
        }

        isEnabled = defaults.bool(forKey: Key.isEnabled)
        showsMenuBarIcon = defaults.bool(forKey: Key.showsMenuBarIcon)
        Self.migrateMainAppLoginItemIfNeeded()
        launchesAtLogin = Self.currentLaunchAtLoginState
    }

    var canManageLaunchAtLogin: Bool {
        if #available(macOS 13.0, *) {
            return true
        }
        return false
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        defaults.set(enabled, forKey: Key.isEnabled)
        onEnabledChange?(enabled)
    }

    func setShowsMenuBarIcon(_ shown: Bool) {
        guard shown != showsMenuBarIcon else { return }
        showsMenuBarIcon = shown
        defaults.set(shown, forKey: Key.showsMenuBarIcon)
        onMenuBarIconChange?(shown)
    }

    func setLaunchesAtLogin(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }

        let service = LoginItemRegistration.service

        do {
            if enabled {
                try Self.unregisterMainAppLoginItemIfNeeded()
                switch service.status {
                case .enabled:
                    break
                case .requiresApproval:
                    launchesAtLogin = true
                    onLoginItemRequiresApproval?()
                    return
                case .notRegistered, .notFound:
                    try service.register()
                @unknown default:
                    try service.register()
                }
                LoginItemRegistration.noteRegistered(defaults: defaults)
            } else {
                if service.status != .notRegistered {
                    try service.unregister()
                }
                try Self.unregisterMainAppLoginItemIfNeeded()
                defaults.removeObject(forKey: Key.loginItemAppCodeHash)
            }

            refreshLaunchAtLoginState()

            if service.status == .requiresApproval {
                onLoginItemRequiresApproval?()
            }
        } catch {
            refreshLaunchAtLoginState()
            onLoginItemError?(error.localizedDescription)
        }
    }

    func refreshLaunchAtLoginState() {
        launchesAtLogin = Self.currentLaunchAtLoginState
    }

    private static var currentLaunchAtLoginState: Bool {
        guard #available(macOS 13.0, *) else { return false }
        let status = LoginItemRegistration.service.status
        return status == .enabled || status == .requiresApproval
    }

    /// Reports a login item registered for a different build.
    ///
    /// The app cannot repair this from its own process -- see
    /// `LoginItemRegistration` for what was measured. Detecting it is still
    /// worth doing: otherwise the only symptom is a login that silently does
    /// nothing.
    func reportStaleLoginItemRegistration() {
        guard #available(macOS 13.0, *) else { return }
        guard LoginItemRegistration.needsRepair(defaults: defaults) else { return }

        NSLog(
            """
            NotchVeil login item is registered for a different build and will             not start at login; run scripts/install.sh, or             '%@/Contents/MacOS/NotchVeil %@' from a terminal
            """,
            Bundle.main.bundleURL.path,
            LoginItemRegistration.standaloneFlag
        )
    }

    private static func migrateMainAppLoginItemIfNeeded() {
        guard #available(macOS 13.0, *) else { return }

        let oldService = SMAppService.mainApp
        let oldIsRegistered = oldService.status == .enabled
            || oldService.status == .requiresApproval
        guard oldIsRegistered else { return }

        do {
            try oldService.unregister()
            if LoginItemRegistration.service.status == .notRegistered {
                try LoginItemRegistration.service.register()
            }
        } catch {
            NSLog("NotchVeil login item migration failed: %@", error.localizedDescription)
        }
    }

    @available(macOS 13.0, *)
    private static func unregisterMainAppLoginItemIfNeeded() throws {
        let service = SMAppService.mainApp
        if service.status != .notRegistered {
            try service.unregister()
        }
    }
}
