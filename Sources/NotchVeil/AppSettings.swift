import Combine
import Foundation
import NotchVeilCore
import Security
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    private static let loginLauncherIdentifier = "com.limdy.NotchVeil.LoginLauncher"

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

        let service = Self.loginLauncherService

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
                rememberRegisteredCodeHash()
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

    /// launchd pins a login item to the code identity it was registered with. An
    /// ad-hoc signature has no stable identity, so replacing the app invalidates
    /// the registration: launchd then fails to spawn the launcher with EX_CONFIG
    /// at every login while `SMAppService` still reports `.enabled`, which makes
    /// the breakage invisible. Re-register whenever the installed app no longer
    /// matches the one we registered for.
    ///
    /// This tracks the *app* bundle rather than the launcher, because the app's
    /// signature seals its nested code -- the launcher can be byte-identical
    /// across a rebuild while the registration is still stale.
    func reconcileLoginItemRegistration() {
        guard #available(macOS 13.0, *) else { return }

        let service = Self.loginLauncherService
        let status = service.status
        guard status == .enabled || status == .requiresApproval else { return }

        guard let installedHash = Self.appCodeHash() else { return }
        guard defaults.string(forKey: Key.loginItemAppCodeHash) != installedHash else { return }

        do {
            if service.status != .notRegistered {
                try service.unregister()
            }
            try service.register()
            defaults.set(installedHash, forKey: Key.loginItemAppCodeHash)
            NSLog("NotchVeil re-registered the login item for %@", installedHash)
        } catch {
            NSLog(
                "NotchVeil could not re-register the login item: %@",
                error.localizedDescription
            )
        }

        refreshLaunchAtLoginState()

        if Self.loginLauncherService.status == .requiresApproval {
            onLoginItemRequiresApproval?()
        }
    }

    private func rememberRegisteredCodeHash() {
        guard let hash = Self.appCodeHash() else { return }
        defaults.set(hash, forKey: Key.loginItemAppCodeHash)
    }

    /// Reads the cdhash of this app bundle, which is the code identity the login
    /// item registration is bound to.
    private static func appCodeHash() -> String? {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(
            Bundle.main.bundleURL as CFURL, [], &staticCode
        ) == errSecSuccess, let staticCode else {
            return nil
        }

        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: 0),   // kSecCSDefaultFlags
            &information
        ) == errSecSuccess else {
            return nil
        }

        guard let details = information as? [String: Any],
              let hash = details[kSecCodeInfoUnique as String] as? Data else {
            return nil
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private static var currentLaunchAtLoginState: Bool {
        guard #available(macOS 13.0, *) else { return false }
        let status = loginLauncherService.status
        return status == .enabled || status == .requiresApproval
    }

    @available(macOS 13.0, *)
    private static var loginLauncherService: SMAppService {
        SMAppService.loginItem(identifier: loginLauncherIdentifier)
    }

    private static func migrateMainAppLoginItemIfNeeded() {
        guard #available(macOS 13.0, *) else { return }

        let oldService = SMAppService.mainApp
        let oldIsRegistered = oldService.status == .enabled
            || oldService.status == .requiresApproval
        guard oldIsRegistered else { return }

        do {
            try oldService.unregister()
            if loginLauncherService.status == .notRegistered {
                try loginLauncherService.register()
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
