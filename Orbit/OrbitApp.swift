import SwiftUI

@main
struct OrbitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 8) {
                Text("Orbit")
                    .font(.headline)

                if !HotkeyManager.hasPermission() {
                    Button("Grant Input Monitoring Permission") {
                        HotkeyManager.requestPermission()
                    }
                } else {
                    let combo = KeyCombo(from: appDelegate.controller?.configManager.config.hotkey ?? .init(key: "space", modifiers: ["control"]))
                    Text("Ready (\(combo.displayName))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

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
