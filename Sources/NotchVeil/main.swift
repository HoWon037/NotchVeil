import AppKit

let application = NSApplication.shared
let controller = NotchVeilController()
application.delegate = controller
application.run()
