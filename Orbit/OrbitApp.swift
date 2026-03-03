import SwiftUI

@main
struct OrbitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 8) {
                Text("Orbit")
                    .font(.headline)

                if let controller = appDelegate.controller, controller.hotkeyManager.isListening {
                    let combo = KeyCombo(from: controller.configManager.config.hotkey)
                    Text("Ready (\(combo.displayName))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not running")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Divider()

                Button("Settings...") {
                    appDelegate.showSettings()
                }

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(4)
        } label: {
            Label("Orbit", systemImage: "circle.grid.2x2")
        }
        .menuBarExtraStyle(.menu)
    }
}
