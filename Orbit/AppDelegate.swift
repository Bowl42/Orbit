import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, ObservableObject {
    @Published var controller: OrbitController?
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        controller = OrbitController()

        if HotkeyManager.hasPermission() {
            controller?.startListening()
        } else {
            showSettings()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showSettings() {
        // Become a regular app first so activate() actually works
        NSApp.setActivationPolicy(.regular)

        if let existing = settingsWindow, existing.isVisible || existing.isMiniaturized {
            if existing.isMiniaturized { existing.deminiaturize(nil) }
            existing.orderFrontRegardless()
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        guard let controller else { return }

        let settingsView = SettingsView(
            configManager: controller.configManager,
            onSave: { [weak self] in
                guard let self, let controller = self.controller else { return }
                controller.applyHotkey()
                if HotkeyManager.hasPermission() && !controller.hotkeyManager.isListening {
                    controller.startListening()
                }
            }
        )

        let hostingView = NSHostingView(rootView: settingsView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Orbit Settings"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.contentView = hostingView
        window.center()
        window.delegate = self
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        settingsWindow = window
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        settingsWindow = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
