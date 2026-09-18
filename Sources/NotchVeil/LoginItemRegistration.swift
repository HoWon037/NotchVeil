import Foundation
import NotchVeilCore
import Security
import ServiceManagement

/// Keeps the login item registration valid across app updates.
///
/// launchd guards a login item with a lightweight code requirement pinned to the
/// launcher's code identity. Replacing the app invalidates it, and the failure
/// is invisible: `launchctl print` reports `needs LWCR update`, `SMAppService`
/// still answers `.enabled`, and every login silently fails with `EX_CONFIG`.
/// That is why logging in only sometimes brought the veil back.
///
/// Re-registering fixes it, but only under two conditions found by testing on
/// macOS 27, and both are needed:
///
/// - at least about a minute must have passed since the bundle changed, and
/// - the registration must come from a process that is not a descendant of the
///   running app.
///
/// Everything else measured had no effect: repeating the cycle in-process, a
/// delay alone, a fresh `SMAppService`, a child spawned with `Process` (with or
/// without the delay), and a second instance launched through LaunchServices.
///
/// So the app does not pretend to fix this itself. It detects the stale
/// registration and says so, and `scripts/install.sh` performs the repair by
/// running this binary with `--register-login-item` from the installing shell,
/// after the settling delay.
enum LoginItemRegistration {
    static let standaloneFlag = "--register-login-item"
    static let identifier = "com.limdy.NotchVeil.LoginLauncher"

    /// How long launchd needs to settle after the bundle changed before a
    /// registration takes. 60s worked in testing; 90 leaves headroom.
    static let settleDelay: TimeInterval = 90

    @available(macOS 13.0, *)
    static var service: SMAppService {
        SMAppService.loginItem(identifier: identifier)
    }

    /// True when the login item is on but was registered for a different build.
    static func needsRepair(defaults: UserDefaults = .standard) -> Bool {
        guard #available(macOS 13.0, *) else { return false }

        let status = service.status
        guard status == .enabled || status == .requiresApproval else { return false }
        guard let installedHash = appCodeHash() else { return false }

        return defaults.string(forKey: NotchVeilDefaultsKey.loginItemAppCodeHash) != installedHash
    }

    /// Performs the repair. The hash is stored only on success, so an app that
    /// is quit before this runs simply tries again on its next launch.
    @discardableResult
    static func repair(defaults: UserDefaults = .standard) -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        guard let installedHash = appCodeHash() else { return false }

        let service = Self.service

        do {
            if service.status != .notRegistered {
                try service.unregister()
                // unregister() returns before launchd has dropped the job, and
                // registering into a half-removed record is its own staleness.
                waitForUnregistration(of: service)
            }

            try service.register()
        } catch {
            NSLog(
                "NotchVeil could not re-register the login item: %@",
                error.localizedDescription
            )
            return false
        }

        defaults.set(installedHash, forKey: NotchVeilDefaultsKey.loginItemAppCodeHash)
        NSLog("NotchVeil login item re-registered for %@", installedHash)
        return true
    }

    @available(macOS 13.0, *)
    static func waitForUnregistration(of service: SMAppService, timeout: TimeInterval = 5) {
        let deadline = Date().addingTimeInterval(timeout)
        while service.status != .notRegistered, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }

    /// Records the current bundle as the registered one, for when the user has
    /// just turned the toggle on and the registration is already current.
    static func noteRegistered(defaults: UserDefaults = .standard) {
        guard let hash = appCodeHash() else { return }
        defaults.set(hash, forKey: NotchVeilDefaultsKey.loginItemAppCodeHash)
    }

    /// The app bundle's cdhash. The app's signature seals its nested code, so
    /// this changes whenever the launcher does.
    static func appCodeHash() -> String? {
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

    /// Entry point for `--register-login-item`: repairs now, with no UI. Run it
    /// from a shell, not from the app, and only after `settleDelay` has passed
    /// since the bundle changed.
    static func runStandaloneAndExit() -> Never {
        guard #available(macOS 13.0, *), service.status != .notRegistered else {
            exit(EXIT_SUCCESS)
        }

        exit(repair() ? EXIT_SUCCESS : EXIT_FAILURE)
    }
}
