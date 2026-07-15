import AppKit

let application = NSApplication.shared
let controller = HeaderController()
application.delegate = controller
application.run()
