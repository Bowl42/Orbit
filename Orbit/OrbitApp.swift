import SwiftUI

@main
struct OrbitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView(appDelegate: appDelegate)
        } label: {
            Image(systemName: "circle.grid.cross")
                .font(.system(size: 14, weight: .semibold))
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Popover View (Spatial Crystal Edition)

private struct MenuBarPopoverView: View {
    @ObservedObject var appDelegate: AppDelegate
    @Environment(\.dismiss) private var dismiss
    
    @State private var animateIn = false

    private var controller: OrbitController? {
        appDelegate.controller
    }

    private var isRunning: Bool {
        controller?.hotkeyManager.isListening ?? false
    }

    var body: some View {
        ZStack {
            // Level 0: Pure Native Light Material
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            // Level 1: Luminous Glow (Top-down lighting)
            LinearGradient(
                colors: [.white.opacity(0.15), .clear, .white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header: Brighter & High Contrast
                header
                
                // Body: Floating Items
                VStack(spacing: 8) {
                    SpatialMenuButton(title: "Settings...", icon: "gearshape.fill") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            self.appDelegate.showSettings()
                        }
                    }
                    
                    SpatialMenuButton(title: "Quit Orbit", icon: "power", color: .red) {
                        NSApp.terminate(nil)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                
                // Footer: Clean metadata
                footer
            }
            .opacity(animateIn ? 1 : 0)
            .scaleEffect(animateIn ? 1 : 0.98)
        }
        .frame(width: 240)
        .preferredColorScheme(.dark) // Keep it dark but make the glass luminous
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                animateIn = true
            }
        }
    }
    
    private var header: some View {
        HStack(spacing: 14) {
            // Branded Icon Hub (Glowing Glass)
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                
                Image(systemName: "circle.grid.cross.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.5), radius: 8)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Orbit")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(isRunning ? "ACTIVE" : "PAUSED")
                    .font(.system(size: 10, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(isRunning ? Color.green : Color.white.opacity(0.4))
            }
            
            Spacer()
            
            // VisionOS Switch
            Button {
                controller?.toggleListening()
            } label: {
                SpatialToggle(isOn: isRunning)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
    
    private var footer: some View {
        HStack {
            Text("v0.1.0")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.2))
            
            Spacer()
            
            if let hotkey = controller?.configManager.config.hotkey {
                HStack(spacing: 4) {
                    Image(systemName: "keyboard.fill").font(.system(size: 8))
                    Text(KeyCombo(from: hotkey).displayName).font(.system(size: 9, weight: .black))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.15))
    }
}

// MARK: - Spatial Components

private struct SpatialToggle: View {
    let isOn: Bool
    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Color.white : Color.white.opacity(0.15))
                .frame(width: 32, height: 18)
            
            Circle()
                .fill(isOn ? Color.black : Color.white)
                .frame(width: 14, height: 14)
                .padding(.horizontal, 2)
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isOn)
    }
}

private struct SpatialMenuButton: View {
    let title: String
    let icon: String
    var color: Color = .white
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 16)
                
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                
                Spacer()
            }
            .foregroundColor(isHovered ? .black : color.opacity(0.9))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    if isHovered {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
