import AppKit
import Foundation
import OSLog

/// Starts the main app at login.
///
/// The previous version opened the app exactly once and exited on the first
/// hiccup, which is why a login occasionally ended with nothing running: at
/// login LaunchServices is still warming up, and a previous session's instance
/// can still be tearing down. This keeps trying until the app is actually up.
private enum LoginLauncher {
    /// A dedicated subsystem, so a failed login leaves evidence that survives to
    /// `log show --predicate 'subsystem == "com.limdy.NotchVeil"'`. Plain NSLog
    /// from a short-lived login agent is routinely dropped, and `.info` is kept
    /// in memory only -- everything here logs at `.notice` or above so it lands
    /// on disk and is still there after the next reboot.
    static let logger = Logger(subsystem: "com.limdy.NotchVeil", category: "LoginLauncher")

    static let mainBundleIdentifier = "com.limdy.NotchVeil"
    static let maximumAttempts = 6
    static let settleDelay: TimeInterval = 2
    static let overallTimeout: TimeInterval = 45

    static let mainAppURL: URL = {
        var url = Bundle.main.bundleURL
        // .../NotchVeil.app/Contents/Library/LoginItems/NotchVeilLoginLauncher.app
        for _ in 0..<4 {
            url.deleteLastPathComponent()
        }
        return url
    }()

    /// An instance that is actually alive. `runningApplications` still lists a
    /// process on its way out, and treating that as success was the other way a
    /// login could silently end up with nothing running.
    static func liveInstance() -> NSRunningApplication? {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: mainBundleIdentifier)
            .first { !$0.isTerminated }
    }

    @MainActor
    static func stop(_ message: String, failed: Bool = false) {
        if failed {
            logger.error("\(message, privacy: .public)")
        } else {
            logger.notice("\(message, privacy: .public)")
        }
        NSApp.terminate(nil)
    }

    @MainActor
    static func run(attempt: Int) {
        if let running = liveInstance() {
            // Confirm it is still there a moment later. A dying instance from
            // the previous session looks identical to a healthy one right now.
            let pid = running.processIdentifier
            DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) {
                MainActor.assumeIsolated {
                    if liveInstance() != nil {
                        stop("NotchVeil is running (pid \(pid))")
                    } else if attempt < maximumAttempts {
                        logger.notice("instance went away while settling, retrying")
                        run(attempt: attempt + 1)
                    } else {
                        stop("NotchVeil kept exiting on launch", failed: true)
                    }
                }
            }
            return
        }

        guard attempt <= maximumAttempts else {
            stop("could not start NotchVeil after \(maximumAttempts) attempts", failed: true)
            return
        }

        guard Bundle(url: mainAppURL)?.bundleIdentifier == mainBundleIdentifier else {
            stop("could not locate the main app at \(mainAppURL.path)", failed: true)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = ["--launch-at-login"]
        configuration.activates = false

        NSWorkspace.shared.openApplication(
            at: mainAppURL,
            configuration: configuration
        ) { _, error in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let error else {
                        // Verify rather than trust the callback: loop back and
                        // confirm the app is really there.
                        run(attempt: attempt + 1)
                        return
                    }

                    guard attempt < maximumAttempts else {
                        stop("giving up: \(error.localizedDescription)", failed: true)
                        return
                    }

                    let delay = min(pow(2, Double(attempt - 1)) * 0.5, 8)
                    logger.error(
                        "attempt \(attempt, privacy: .public) failed: \(error.localizedDescription, privacy: .public), retrying in \(delay, privacy: .public)s"
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        MainActor.assumeIsolated { run(attempt: attempt + 1) }
                    }
                }
            }
        }
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.prohibited)

DispatchQueue.main.async {
    MainActor.assumeIsolated { LoginLauncher.run(attempt: 1) }
}

// Never outlive the job: if something wedges, exit rather than linger.
DispatchQueue.main.asyncAfter(deadline: .now() + LoginLauncher.overallTimeout) {
    MainActor.assumeIsolated {
        LoginLauncher.stop("timed out waiting for NotchVeil to start", failed: true)
    }
}

application.run()
