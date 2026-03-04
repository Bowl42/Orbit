import SwiftUI

@main
struct OrbitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView(appDelegate: appDelegate)
        } label: {
            Image(systemName: "circle.grid.cross")
                .font(.system(size: 14))
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Popover View

private struct MenuBarPopoverView: View {
    @ObservedObject var appDelegate: AppDelegate
    @Environment(\.dismiss) private var dismiss

    private var controller: OrbitController? {
        appDelegate.controller
    }

    private var isRunning: Bool {
        controller?.hotkeyManager.isListening ?? false
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
    }

    private var hotkeyDescription: String {
        guard let config = controller?.configManager.config else { return "Not configured" }
        return KeyCombo(from: config.hotkey).displayName
    }

    var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "circle.grid.cross.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Orbit")
                        .font(.headline)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(isRunning ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                        Text(isRunning ? "Active" : "Inactive")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(hotkeyDescription)
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.bottom, 4)

            Divider()

            // Glass-style action buttons
            Button {
                let delegate = appDelegate
                dismiss()
                DispatchQueue.main.async {
                    delegate.showSettings()
                }
            } label: {
                Label("Settings...", systemImage: "gearshape")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Orbit", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .tint(.pink)

            // Footer
            Text("Version \(version)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(width: 240)
    }
}
