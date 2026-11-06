import Foundation
import NotchVeilCore
import OSLog
import Security
import ServiceManagement

/// Repairs stale login-item registrations after an app update.
/// Ad-hoc signing may require delayed registration from the installer process;
/// see docs/development.md for the environment-specific limitation.
enum LoginItemRegistration {
    static let logger = Logger(subsystem: "com.limdy.NotchVeil", category: "LoginItem")
    static let standaloneFlag = "--register-login-item"
    static let identifier = "com.limdy.NotchVeil.LoginLauncher"

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

    /// Store the new hash only after registration returns successfully.
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
                guard waitForUnregistration(of: service) else {
                    logger.error("login item unregistration timed out; registration was not attempted")
                    return false
                }
            }

            try service.register()
        } catch {
            logger.error("could not re-register login item: \(error.localizedDescription, privacy: .private)")
            return false
        }

        defaults.set(installedHash, forKey: NotchVeilDefaultsKey.loginItemAppCodeHash)
        logger.notice("login item re-registered")
        return true
    }

    @available(macOS 13.0, *)
    static func waitForUnregistration(of service: SMAppService, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while service.status != .notRegistered, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return service.status == .notRegistered
    }

    /// Records the current bundle as the registered one, for when the user has
    /// just turned the toggle on and the registration is already current.
    static func noteRegistered(defaults: UserDefaults = .standard) {
        guard let hash = appCodeHash() else { return }
        defaults.set(hash, forKey: NotchVeilDefaultsKey.loginItemAppCodeHash)
    }

    /// The signed app's cdhash, including its sealed nested code.
    static func appCodeHash() -> String? {
        var staticCode: SecStaticCode?
        guard
            SecStaticCodeCreateWithPath(
                Bundle.main.bundleURL as CFURL, [], &staticCode
            ) == errSecSuccess, let staticCode
        else {
            return nil
        }

        var information: CFDictionary?
        guard
            SecCodeCopySigningInformation(
                staticCode,
                SecCSFlags(rawValue: 0),  // kSecCSDefaultFlags
                &information
            ) == errSecSuccess
        else {
            return nil
        }

        guard let details = information as? [String: Any],
            let hash = details[kSecCodeInfoUnique as String] as? Data
        else {
            return nil
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// Entry point for `--register-login-item`: repairs now, with no UI. Run it
    /// from a shell, not from the app, after allowing the bundle change to
    /// settle (the installer supplies this delay). Explicit registration intent:
    /// retry even when an earlier repair removed the job before failing.
    static func runStandaloneAndExit() -> Never {
        guard #available(macOS 13.0, *) else {
            logger.error("login item registration requires macOS 13 or later")
            exit(EXIT_FAILURE)
        }

        exit(repair() ? EXIT_SUCCESS : EXIT_FAILURE)
    }
}
