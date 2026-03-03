import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: OrbitController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        controller = OrbitController()
        controller?.startListening()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
