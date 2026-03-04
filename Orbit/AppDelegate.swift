import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
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
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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
        let contentSize = hostingView.intrinsicContentSize
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Orbit Settings"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }
}
