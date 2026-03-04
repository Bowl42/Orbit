import AppKit

log("[Ring] main start")
let app = NSApplication.shared
log("[Ring] app created")
let delegate = AppDelegate()
log("[Ring] delegate created")
app.delegate = delegate
log("[Ring] app.run()")
app.run()
