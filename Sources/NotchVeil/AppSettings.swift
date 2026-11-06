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
    @Published private(set) var language: AppLanguage

    var onEnabledChange: ((Bool) -> Void)?
    var onMenuBarIconChange: ((Bool) -> Void)?
    var onLanguageChange: (() -> Void)?
    var onLoginItemError: ((String) -> Void)?
    var onLoginItemRequiresApproval: (() -> Void)?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = .restored(defaults.string(forKey: Key.language))

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

    func text(_ key: AppText) -> String { language.text(key) }

    func setLanguage(_ value: AppLanguage) {
        guard language != value else { return }
        language = value
        defaults.set(value.rawValue, forKey: Key.language)
        onLanguageChange?()
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

    /// Log stale registrations; the installer performs the repair out of process.
    func reportStaleLoginItemRegistration() {
        guard #available(macOS 13.0, *) else { return }
        guard LoginItemRegistration.needsRepair(defaults: defaults) else { return }

        LoginItemRegistration.logger.notice(
            "NotchVeil login item may be stale. See the signing and login-item troubleshooting guide."
        )
    }

    private static func migrateMainAppLoginItemIfNeeded() {
        guard #available(macOS 13.0, *) else { return }

        let oldService = SMAppService.mainApp
        let oldIsRegistered =
            oldService.status == .enabled
            || oldService.status == .requiresApproval
        guard oldIsRegistered else { return }

        do {
            try oldService.unregister()
            if LoginItemRegistration.service.status == .notRegistered {
                try LoginItemRegistration.service.register()
            }
        } catch {
            LoginItemRegistration.logger.error(
                "login item migration failed: \(error.localizedDescription, privacy: .private)"
            )
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
