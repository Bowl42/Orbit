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
                    Text("Ready (Ctrl+Space)")
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
