import Carbon.HIToolbox
import SwiftUI
import Observation

// MARK: - visionOS 2.0 Ultra-Spatial Design System (Adaptive Edition)

private enum Spatial {
    static let windowWidth: CGFloat = 920
    static let windowHeight: CGFloat = 640
    
    static let glassRadius: CGFloat = 38
    static let cardRadius: CGFloat = 28
    static let itemRadius: CGFloat = 16
    
    // Adaptive Palette
    static var rimStroke: Color { Color.primary.opacity(0.15) }
    
    static let fontTitle: Font = .system(size: 24, weight: .bold, design: .rounded)
    static let fontHeader: Font = .system(size: 15, weight: .bold, design: .rounded)
    static let fontLabel: Font = .system(size: 13, weight: .bold, design: .rounded)
    static let fontBody: Font = .system(size: 14, weight: .medium, design: .rounded)
    static let fontCaption: Font = .system(size: 11, weight: .heavy, design: .rounded)
}

// MARK: - ViewModel (Stable)

@MainActor
@Observable
final class SettingsViewModel {
    let configManager: ConfigManager
    let onSave: () -> Void

    var accessibilityGranted = HotkeyManager.hasPermission()
    var inputMonitoringGranted = CGPreflightListenEventAccess()
    
    var hotkeyKey = ""
    var hotkeyType = ""
    var hotkeyModifiers: [String] = []
    
    var sectorConfigs: [OrbitConfig.SectorConfig] = []
    var selectedSectorIndex: Int = 0
    var installedApps: [InstalledApp] = []
    var isLoadingApps = false
    
    var currentTab: SettingsTab = .general
    
    init(configManager: ConfigManager, onSave: @escaping () -> Void) {
        self.configManager = configManager
        self.onSave = onSave
        loadFromConfig()
    }
    
    func loadFromConfig() {
        let config = configManager.config
        let hotkey = config.hotkey
        hotkeyKey = hotkey.key
        hotkeyType = hotkey.isMouseTrigger ? "mouse" : "keyboard"
        hotkeyModifiers = hotkey.modifiers

        let count = config.sectorCount
        var loaded = config.sectors
        while loaded.count < count { loaded.append(.recent(index: loaded.count)) }
        sectorConfigs = Array(loaded.prefix(count))
    }
    
    func refreshPermissions() {
        accessibilityGranted = HotkeyManager.hasPermission()
        inputMonitoringGranted = CGPreflightListenEventAccess()
    }
    
    func fetchApps() async {
        guard installedApps.isEmpty else { return }
        isLoadingApps = true
        installedApps = await InstalledAppsFinder.findAll()
        isLoadingApps = false
    }
    
    func save() {
        configManager.config.hotkey = OrbitConfig.HotkeyConfig(type: hotkeyType, key: hotkeyKey, modifiers: hotkeyModifiers)
        var recentIdx = 0
        configManager.config.sectors = sectorConfigs.map { sector in
            if case .recent = sector {
                defer { recentIdx += 1 }
                return .recent(index: recentIdx)
            }
            return sector
        }
        configManager.saveConfig()
        onSave()
        close()
    }
    
    func close() {
        if let window = NSApp.windows.first(where: { $0.title == "Orbit Settings" }) {
            window.close()
        }
    }
}

enum SettingsTab: String, CaseIterable {
    case general = "General", sectors = "Sectors"
}

// MARK: - Main View

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Namespace private var spatialNamespace
    @Environment(\.colorScheme) var colorScheme
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(configManager: ConfigManager, onSave: @escaping () -> Void) {
        _viewModel = State(initialValue: SettingsViewModel(configManager: configManager, onSave: onSave))
    }

    var body: some View {
        ZStack {
            // Level 0: The Immersive Material (Naturally adaptive)
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            // Level 1: Dynamic Tint
            (colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.1))
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                topNavigation
                
                // Content
                ZStack {
                    if viewModel.currentTab == .general {
                        generalTab
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        sectorsTab
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.currentTab)
                
                // Footer
                footerActions
            }
        }
        .frame(width: Spatial.windowWidth, height: Spatial.windowHeight)
        .task { await viewModel.fetchApps() }
        .onReceive(timer) { _ in viewModel.refreshPermissions() }
    }
    
    private var topNavigation: some View {
        HStack(spacing: 24) {
            HStack(spacing: 12) {
                Image(systemName: "circle.grid.cross.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .shadow(color: .primary.opacity(0.2), radius: 8)
                Text("Orbit")
                    .font(Spatial.fontTitle)
                    .foregroundStyle(.primary)
                    .tracking(-0.5)
            }
            Spacer()
            
            // Adaptive Tab Ornament
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button { viewModel.currentTab = tab } label: {
                        Text(tab.rawValue)
                            .font(Spatial.fontHeader)
                            .padding(.horizontal, 20).padding(.vertical, 8)
                            .background(ZStack {
                                if viewModel.currentTab == tab {
                                    Capsule()
                                        .fill(colorScheme == .dark ? .white : .black)
                                        .matchedGeometryEffect(id: "tab", in: spatialNamespace)
                                        .shadow(color: .primary.opacity(0.2), radius: 10, y: 4)
                                }
                            })
                            .foregroundStyle(viewModel.currentTab == tab ? (colorScheme == .dark ? .black : .white) : .primary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color.primary.opacity(0.05))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Spatial.rimStroke, lineWidth: 0.5))
            
            Spacer()
            
            Text("PREFERENCES").font(Spatial.fontCaption).foregroundStyle(.primary.opacity(0.2)).tracking(2)
        }
        .padding(.horizontal, 48)
        .frame(height: 100)
    }
    
    private var footerActions: some View {
        HStack(spacing: 24) {
            Spacer()
            SpatialAdaptiveButton(title: "Cancel", isDefault: false) { viewModel.close() }
            SpatialAdaptiveButton(title: "Save Changes", isDefault: true) { viewModel.save() }
        }
        .padding(.horizontal, 48)
        .padding(.bottom, 48)
    }
    
    private var generalTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                SpatialSectionBox(title: "Security & Access", icon: "shield.fill") {
                    VStack(spacing: 12) {
                        SpatialPermissionLine(title: "Accessibility API", isGranted: viewModel.accessibilityGranted) {
                            openPrivacySettings(for: "Privacy_Accessibility")
                        }
                        Divider().opacity(0.05)
                        SpatialPermissionLine(title: "Input Monitoring", isGranted: viewModel.inputMonitoringGranted) {
                            CGRequestListenEventAccess(); openPrivacySettings(for: "Privacy_ListenEvent")
                        }
                    }
                }
                
                SpatialSectionBox(title: "Activation", icon: "keyboard") {
                    VStack(alignment: .leading, spacing: 16) {
                        SpatialHotkeyRecorderBox(key: $viewModel.hotkeyKey, type: $viewModel.hotkeyType, modifiers: $viewModel.hotkeyModifiers)
                        Text("Hold key to summon, release to activate. Supports mouse side buttons.")
                            .font(Spatial.fontCaption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 48)
            .padding(.top, 20)
            .frame(maxWidth: 680)
        }
    }
    
    private var sectorsTab: some View {
        HStack(spacing: 0) {
            VStack(spacing: 40) {
                Text("RADIAL LAYOUT").font(Spatial.fontCaption).foregroundStyle(.secondary).tracking(2)
                SpatialRingPreviewAdaptive(configs: viewModel.sectorConfigs, selectedIndex: $viewModel.selectedSectorIndex, apps: viewModel.installedApps)
                    .frame(width: 300, height: 300)
                Text("Select slot to configure").font(Spatial.fontCaption).foregroundStyle(.secondary)
            }
            .frame(width: 400)
            
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("MODULE TYPE").font(Spatial.fontCaption).foregroundStyle(.secondary).tracking(1)
                    ActionTypeAdaptiveFlow(selection: sectorKindBinding)
                }
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Spatial.rimStroke, lineWidth: 0.5))
                
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        EditorPaneGridAdaptive(config: $viewModel.sectorConfigs[viewModel.selectedSectorIndex], apps: viewModel.installedApps, isLoading: viewModel.isLoadingApps)
                            .padding(24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Spatial.rimStroke, lineWidth: 0.5))
            }
            .padding(.trailing, 48)
            .padding(.bottom, 20)
        }
    }
    
    private var sectorKindBinding: Binding<SectorKind> {
        Binding(
            get: { SectorKind(from: viewModel.sectorConfigs[viewModel.selectedSectorIndex]) },
            set: { k in
                withAnimation(.spring(response: 0.3)) {
                    switch k {
                    case .recent: viewModel.sectorConfigs[viewModel.selectedSectorIndex] = .recent(index: 0)
                    case .pinned: viewModel.sectorConfigs[viewModel.selectedSectorIndex] = .pinned(bundleId: "", name: "", icon: nil)
                    case .url: viewModel.sectorConfigs[viewModel.selectedSectorIndex] = .url(name: "", url: "", icon: nil)
                    case .system: viewModel.sectorConfigs[viewModel.selectedSectorIndex] = .systemAction(action: .lockScreen)
                    case .shell: viewModel.sectorConfigs[viewModel.selectedSectorIndex] = .shellCommand(name: "", command: "", icon: nil)
                    case .translate: viewModel.sectorConfigs[viewModel.selectedSectorIndex] = .translate
                    }
                }
            }
        )
    }

    private func openPrivacySettings(for pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
    }
}

// MARK: - Adaptive Components

private struct SpatialSectionBox<Content: View>: View {
    let title: String; let icon: String; let content: Content
    @Environment(\.colorScheme) var colorScheme
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.icon = icon; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title.uppercased(), systemImage: icon).font(Spatial.fontCaption).foregroundStyle(.secondary).padding(.leading, 12)
            content.padding(24)
                .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                .cornerRadius(Spatial.cardRadius)
                .overlay(RoundedRectangle(cornerRadius: Spatial.cardRadius, style: .continuous).stroke(Spatial.rimStroke, lineWidth: 0.5))
        }
    }
}

private struct SpatialPermissionLine: View {
    let title: String; let isGranted: Bool; let onGrant: () -> Void
    var body: some View {
        HStack {
            Text(title).font(Spatial.fontBody).bold().foregroundStyle(.primary)
            Spacer()
            if isGranted {
                Text("READY").font(Spatial.fontCaption).foregroundStyle(.background).padding(.horizontal, 12).padding(.vertical, 6).background(Color.primary).clipShape(Capsule())
            } else {
                Button("Configure") { onGrant() }.buttonStyle(.bordered).controlSize(.small)
            }
        }
    }
}

private struct SpatialHotkeyRecorderBox: View {
    @Binding var key: String; @Binding var type: String; @Binding var modifiers: [String]
    @State private var isRecording = false
    var body: some View {
        HStack(spacing: 12) {
            Text(isRecording ? "WAITING FOR INPUT..." : KeyCombo(key: key, modifiers: modifiers).displayName)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).frame(height: 52).background(Color.primary.opacity(0.06)).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Spatial.rimStroke, lineWidth: 0.5))
            Button(isRecording ? "Cancel" : "Rebind") { isRecording.toggle() }.buttonStyle(.bordered).controlSize(.large)
        }
        .background {
            if isRecording {
                HotkeyRecorderHelper(onKeyRecorded: { k, m in
                    key = k; type = k.hasPrefix("mouse") ? "mouse" : "keyboard"; modifiers = m; isRecording = false
                }, onCancel: { isRecording = false })
            }
        }
    }
}

private struct SpatialRingPreviewAdaptive: View {
    let configs: [OrbitConfig.SectorConfig]; @Binding var selectedIndex: Int; let apps: [InstalledApp]
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
            ZStack {
                Circle().stroke(Color.primary.opacity(0.05), lineWidth: 1).frame(width: 200, height: 200)
                ForEach(configs.indices, id: \.self) { i in
                    let a = Angle.degrees(Double(i)*(360.0/Double(configs.count))-90)
                    Button { withAnimation(.spring(response: 0.3)) { selectedIndex = i } } label: {
                        ZStack {
                            Circle().fill(i == selectedIndex ? Color.primary : Color.primary.opacity(0.1)).frame(width: 56, height: 56)
                            previewIcon(for: configs[i]).resizable().aspectRatio(contentMode: .fit).frame(width: 28, height: 28)
                                .foregroundStyle(i == selectedIndex ? (colorScheme == .dark ? .black : .white) : .primary.opacity(0.8))
                        }
                        .overlay(Circle().stroke(Color.primary.opacity(i == selectedIndex ? 0.6 : 0.1), lineWidth: 1))
                        .scaleEffect(i == selectedIndex ? 1.15 : 1.0)
                        .shadow(color: Color.primary.opacity(i == selectedIndex ? 0.3 : 0), radius: 15)
                    }
                    .buttonStyle(.plain).position(x: center.x+cos(a.radians)*100, y: center.y+sin(a.radians)*100)
                }
            }
        }
    }
    private func previewIcon(for config: OrbitConfig.SectorConfig) -> Image {
        switch config {
        case .recent: return Image(systemName: "sparkles")
        case .pinned(let bid, _, _):
            if let app = apps.first(where: { $0.bundleId == bid }) { return Image(nsImage: app.icon) }
            return Image(systemName: "app.dashed")
        case .url: return Image(systemName: "link")
        case .systemAction(let action): return Image(systemName: action.sfSymbolName)
        case .shellCommand: return Image(systemName: "terminal")
        case .translate: return Image(systemName: "translate")
        default: return Image(systemName: "app")
        }
    }
}

private struct ActionTypeAdaptiveFlow: View {
    @Binding var selection: SectorKind
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SectorKind.allCases, id: \.self) { kind in
                    Button { withAnimation(.spring(response: 0.3)) { selection = kind } } label: {
                        Text(kind.rawValue).font(Spatial.fontLabel)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(ZStack {
                                if selection == kind {
                                    Capsule().fill(colorScheme == .dark ? .white : .black)
                                } else {
                                    Capsule().fill(Color.primary.opacity(0.08))
                                }
                            })
                            .foregroundStyle(selection == kind ? (colorScheme == .dark ? .black : .white) : .primary.opacity(0.7))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct EditorPaneGridAdaptive: View {
    @Binding var config: OrbitConfig.SectorConfig; let apps: [InstalledApp]; let isLoading: Bool
    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            switch config {
            case .recent:
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dynamic Launcher").font(Spatial.fontHeader).foregroundStyle(.primary)
                    Text("Automatically mirrors last active application icon.").font(Spatial.fontBody).foregroundStyle(.secondary)
                }
            case .pinned(let bid, _, _):
                VStack(spacing: 16) {
                    TextField("Filter applications...", text: $searchText).textFieldStyle(.plain).padding(12).background(Color.primary.opacity(0.06)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Spatial.rimStroke, lineWidth: 0.5))
                    if isLoading { ProgressView().controlSize(.small) }
                    else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 85), spacing: 12)], spacing: 16) {
                            ForEach(apps.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }.prefix(100)) { app in
                                Button { config = .pinned(bundleId: app.bundleId, name: app.name, icon: nil) } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            Image(nsImage: app.icon).resizable().frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 12))
                                            if bid == app.bundleId {
                                                RoundedRectangle(cornerRadius: 14).stroke(Color.primary, lineWidth: 3).frame(width: 56, height: 56)
                                            }
                                        }
                                        Text(app.name).font(Spatial.fontCaption).lineLimit(1).foregroundStyle(bid == app.bundleId ? .primary : .secondary)
                                    }.frame(width: 85)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            case .url(let name, let url, _):
                VStack(spacing: 24) {
                    SpatialAdaptiveInput(label: "LABEL", text: Binding(get: { name }, set: { config = .url(name: $0, url: url, icon: nil) }), placeholder: "Label")
                    SpatialAdaptiveInput(label: "URI", text: Binding(get: { url }, set: { config = .url(name: name, url: $0, icon: nil) }), placeholder: "https://")
                }
            case .systemAction(let action):
                VStack(spacing: 10) {
                    ForEach(OrbitConfig.SystemActionKind.allCases, id: \.self) { k in
                        Button { withAnimation(.spring(response: 0.2)) { config = .systemAction(action: k) } } label: {
                            HStack(spacing: 16) {
                                Image(systemName: k.sfSymbolName).font(.system(size: 16, weight: .bold)).frame(width: 24)
                                Text(k.displayName).font(Spatial.fontBody).bold()
                                Spacer()
                                if action == k { Image(systemName: "checkmark.circle.fill").foregroundStyle(.primary).font(.system(size: 18)) }
                            }
                            .padding(.horizontal, 20).padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(action == k ? Color.primary.opacity(0.15) : Color.primary.opacity(0.03)))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(action == k ? 0.2 : 0), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            case .shellCommand(let name, let cmd, _):
                VStack(spacing: 24) {
                    SpatialAdaptiveInput(label: "ALIAS", text: Binding(get: { name }, set: { config = .shellCommand(name: $0, command: cmd, icon: nil) }), placeholder: "Script Name")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COMMAND").font(Spatial.fontCaption).foregroundStyle(.secondary).tracking(1)
                        TextEditor(text: Binding(get: { cmd }, set: { config = .shellCommand(name: name, command: $0, icon: nil) }))
                            .font(.system(size: 13, design: .monospaced))
                            .frame(height: 160).padding(14).background(Color.primary.opacity(0.06)).cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Spatial.rimStroke, lineWidth: 0.5))
                    }
                }
            default: Text("Ready").foregroundStyle(.secondary)
            }
        }
    }
}

private struct SpatialAdaptiveInput: View {
    let label: String; @Binding var text: String; let placeholder: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(Spatial.fontCaption).foregroundStyle(.secondary).tracking(1)
            TextField(placeholder, text: $text).textFieldStyle(.plain).padding(16)
                .background(Color.primary.opacity(0.06)).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Spatial.rimStroke, lineWidth: 0.5))
        }
    }
}

private struct SpatialAdaptiveButton: View {
    let title: String; let isDefault: Bool; let action: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        Button(action: action) {
            Text(title).font(Spatial.fontBody).bold()
                .padding(.horizontal, 32).padding(.vertical, 14)
                .background(isDefault ? Color.blue : (isHovered ? Color.primary.opacity(0.2) : Color.primary.opacity(0.1)))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.25), lineWidth: 0.5))
                .shadow(color: isDefault ? Color.blue.opacity(0.3) : .clear, radius: 15, y: 5)
                .foregroundStyle(isDefault ? .white : .primary)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Helpers

private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material; let blendingMode: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView(); v.material = material; v.blendingMode = blendingMode; v.state = .active; return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private enum SectorKind: String, CaseIterable {
    case recent = "Recent", pinned = "App", url = "URL", system = "System", shell = "Shell", translate = "Translate"
    init(from config: OrbitConfig.SectorConfig) {
        switch config {
        case .recent: self = .recent; case .pinned: self = .pinned; case .url: self = .url
        case .systemAction: self = .system; case .shellCommand: self = .shell
        case .translate: self = .translate; default: self = .recent
        }
    }
}

private struct HotkeyRecorderHelper: NSViewRepresentable {
    let onKeyRecorded: (String, [String]) -> Void; let onCancel: () -> Void
    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let v = HotkeyRecorderNSView(); v.onKeyRecorded = onKeyRecorded; v.onCancel = onCancel
        return v
    }
    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {}
}

private final class HotkeyRecorderNSView: NSView {
    var onKeyRecorded: ((String, [String]) -> Void)?; var onCancel: (() -> Void)?
    private var monitor: Any?
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if window != nil { startM() } else { stopM() } }
    private func startM() {
        stopM()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .otherMouseDown, .rightMouseDown]) { [weak self] e in
            guard let self = self else { return e }
            if e.type == .keyDown {
                if e.keyCode == 53 { self.onCancel?(); return nil }
                if let n = KeyCombo.keyNames[Int64(e.keyCode)] { self.onKeyRecorded?(n, self.mods(f: e.modifierFlags)); return nil }
            } else {
                self.onKeyRecorded?("mouse\(e.buttonNumber + 1)", self.mods(f: e.modifierFlags)); return nil
            }
            return e
        }
    }
    private func stopM() { if let m = monitor { NSEvent.removeMonitor(m); monitor = nil } }
    private func mods(f: NSEvent.ModifierFlags) -> [String] {
        var m: [String] = []
        if f.contains(.control) { m.append("control") }; if f.contains(.option) { m.append("option") }
        if f.contains(.shift) { m.append("shift") }; if f.contains(.command) { m.append("command") }
        return m
    }
}
