import SwiftUI

@main
struct OrbitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            VStack {
                Text("Orbit")
                    .font(.headline)
                Divider()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        } label: {
            Label("Orbit", systemImage: "circle.grid.2x2")
        }
        .menuBarExtraStyle(.menu)
    }
}
