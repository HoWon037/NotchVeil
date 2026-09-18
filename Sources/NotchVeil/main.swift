import AppKit

// A second registration from a separate process is the only thing that makes
// launchd pick up a new code requirement for the login item.
if CommandLine.arguments.contains(LoginItemRegistration.standaloneFlag) {
    LoginItemRegistration.runStandaloneAndExit()
}

let application = NSApplication.shared
let controller = NotchVeilController()
application.delegate = controller
application.run()
