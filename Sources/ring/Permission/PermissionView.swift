import SwiftUI

struct PermissionView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "computermouse.fill")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Input Monitoring Required")
                    .font(.title2.bold())
                Text("Ring needs Input Monitoring permission to detect mouse buttons 4 and 5 globally.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            VStack(spacing: 10) {
                Button(action: openSystemSettings) {
                    Label("Open System Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("Go to **Privacy & Security → Input Monitoring**, then enable **ring**.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(width: 400)
    }

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
