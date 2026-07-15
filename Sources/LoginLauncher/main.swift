import AppKit
import Foundation

private let mainBundleIdentifier = "com.limdy.NotchVeil"

let application = NSApplication.shared
application.setActivationPolicy(.prohibited)

guard NSRunningApplication.runningApplications(
    withBundleIdentifier: mainBundleIdentifier
).isEmpty else {
    exit(EXIT_SUCCESS)
}

var mainAppURL = Bundle.main.bundleURL
for _ in 0..<4 {
    mainAppURL.deleteLastPathComponent()
}

guard Bundle(url: mainAppURL)?.bundleIdentifier == mainBundleIdentifier else {
    NSLog("NotchVeil login launcher could not locate the main app")
    exit(EXIT_SUCCESS)
}

let configuration = NSWorkspace.OpenConfiguration()
configuration.arguments = ["--launch-at-login"]
configuration.activates = false

NSWorkspace.shared.openApplication(
    at: mainAppURL,
    configuration: configuration
) { _, error in
    if let error {
        NSLog("NotchVeil login launcher failed: %@", error.localizedDescription)
    }
    DispatchQueue.main.async {
        NSApp.terminate(nil)
    }
}

application.run()
