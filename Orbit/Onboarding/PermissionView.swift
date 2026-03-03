import SwiftUI

struct PermissionView: View {
    @State private var isGranted = HotkeyManager.hasPermission()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var onPermissionGranted: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "keyboard.badge.eye")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Orbit Needs Input Monitoring")
                .font(.title2.bold())

            Text("Orbit needs Input Monitoring permission to detect your hotkey (Ctrl+Space) globally. This only listens for your configured shortcut — Orbit does not record or transmit any keystrokes.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)

            if isGranted {
                Label("Permission Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            } else {
                Button("Open System Settings") {
                    HotkeyManager.requestPermission()
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("After enabling, Orbit will automatically continue.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(40)
        .frame(width: 440, height: 320)
        .onReceive(timer) { _ in
            isGranted = HotkeyManager.hasPermission()
            if isGranted {
                onPermissionGranted()
            }
        }
    }
}
