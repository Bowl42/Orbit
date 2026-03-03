import SwiftUI

@main
struct OrbitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView(appDelegate: appDelegate)
        } label: {
            // The icon in the menu bar.
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
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "circle.grid.cross.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.accentColor)
                    
                    Text("Orbit")
                        .font(.largeTitle.weight(.heavy))
                    
                    Spacer()
                }

                HStack {
                    Circle()
                        .fill(isRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                        .shadow(color: (isRunning ? Color.green : Color.red).opacity(0.5), radius: 3, x: 0, y: 0)
                    
                    Text(isRunning ? "Active" : "Inactive")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(hotkeyDescription)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            
            Divider()
            
            // Action Buttons
            VStack(spacing: 0) {
                Button {
                    dismiss()
                    appDelegate.showSettings()
                } label: {
                    Label("Settings...", systemImage: "gearshape.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .padding(12)

                Divider()
                
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit Orbit", systemImage: "power.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .padding(12)
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("Version \(version)")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.3))
        }
        .frame(width: 280)
    }
}
