import AppKit

// A read-only readiness probe for the installer. Match this bundle, not just a
// process name (another build may also be running).
if CommandLine.arguments.contains("--check-running") {
    let target = Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL
    let ready = NSRunningApplication.runningApplications(withBundleIdentifier: "com.limdy.NotchVeil")
        .contains {
            $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
                && !$0.isTerminated && $0.isFinishedLaunching
                && $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == target
        }
    exit(ready ? EXIT_SUCCESS : EXIT_FAILURE)
}

// The installer repairs login-item registrations outside the running app.
if CommandLine.arguments.contains(LoginItemRegistration.standaloneFlag) {
    LoginItemRegistration.runStandaloneAndExit()
}

let application = NSApplication.shared
let controller = NotchVeilController()
application.delegate = controller
application.run()
