import SwiftUI

@main
struct OrbitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appDelegate: appDelegate)
        } label: {
            Image(systemName: "circle.grid.cross")
                .font(.system(size: 14, weight: .semibold))
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarView: View {
    @ObservedObject var appDelegate: AppDelegate

    private var controller: OrbitController? { appDelegate.controller }
    private var isRunning: Bool { controller?.hotkeyManager.isListening ?? false }

    var body: some View {
        Text(isRunning ? "Orbit — Active" : "Orbit — Paused")
            .foregroundStyle(.secondary)

        Divider()

        Button(isRunning ? "Pause Orbit" : "Resume Orbit") {
            controller?.toggleListening()
        }

        Button("Settings...") {
            appDelegate.showSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        if let hotkey = controller?.configManager.config.hotkey {
            Text("Trigger: \(KeyCombo(from: hotkey).displayName)")
                .foregroundStyle(.secondary)
            Divider()
        }

        Button("Quit Orbit") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
