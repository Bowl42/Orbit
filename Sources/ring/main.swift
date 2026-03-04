import AppKit

print("[Ring] main start")
let app = NSApplication.shared
print("[Ring] app created")
let delegate = AppDelegate()
print("[Ring] delegate created")
app.delegate = delegate
print("[Ring] app.run()")
app.run()
