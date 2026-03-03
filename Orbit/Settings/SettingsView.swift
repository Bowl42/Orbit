import SwiftUI

struct SettingsView: View {
    let configManager: ConfigManager
    let onSave: () -> Void

    @State private var accessibilityGranted = HotkeyManager.hasPermission()
    @State private var inputMonitoringGranted = CGPreflightListenEventAccess()

    @State private var triggerType: TriggerType = .keyboard
    @State private var selectedKey: String = "space"
    @State private var selectedMouseButton: String = "mouse4"
    @State private var useCommand = false
    @State private var useShift = false
    @State private var useOption = false
    @State private var useControl = false

    @State private var sectorConfigs: [OrbitConfig.SectorConfig] = (0..<8).map { .recent(index: $0) }
    @State private var selectedSectorIndex: Int = 0
    @State private var showingAppPicker = false
    @State private var installedApps: [InstalledApp] = []

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var allPermissionsGranted: Bool {
        accessibilityGranted && inputMonitoringGranted
    }

    enum TriggerType: String, CaseIterable {
        case keyboard = "Keyboard Hotkey"
        case mouse = "Mouse Button"
    }

    static let availableKeys: [(label: String, value: String)] = [
        ("Space", "space"), ("Return", "return"), ("Tab", "tab"), ("Escape", "escape"),
    ] + (UnicodeScalar("a").value...UnicodeScalar("z").value).map {
        let ch = String(UnicodeScalar($0)!)
        return (ch.uppercased(), ch)
    }

    static let mouseButtons: [(label: String, value: String)] = [
        ("Middle Button", "mouse3"), ("Side Button 1 (Back)", "mouse4"), ("Side Button 2 (Forward)", "mouse5"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                GeneralTab(
                    accessibilityGranted: accessibilityGranted,
                    inputMonitoringGranted: inputMonitoringGranted,
                    allPermissionsGranted: allPermissionsGranted,
                    triggerType: $triggerType,
                    selectedKey: $selectedKey,
                    selectedMouseButton: $selectedMouseButton,
                    useControl: $useControl,
                    useOption: $useOption,
                    useShift: $useShift,
                    useCommand: $useCommand,
                    previewText: previewText,
                    openPrivacySettings: openPrivacySettings
                )
                .tabItem { Label("General", systemImage: "gearshape") }

                SectorsTab(
                    sectorConfigs: $sectorConfigs,
                    selectedSectorIndex: $selectedSectorIndex,
                    showingAppPicker: $showingAppPicker,
                    installedApps: installedApps
                )
                .tabItem { Label("Sectors", systemImage: "circle.grid.cross") }
            }

            HStack {
                Text("Orbit v1.0")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Save and Restart") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator), alignment: .top)
        }
        .frame(width: 520, height: 520)
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(apps: installedApps) { app in
                sectorConfigs[selectedSectorIndex] = .pinned(
                    bundleId: app.bundleId,
                    name: app.name,
                    icon: nil
                )
            }
        }
        .onAppear(perform: loadFromConfig)
        .onReceive(timer) { _ in
            withAnimation {
                accessibilityGranted = HotkeyManager.hasPermission()
                inputMonitoringGranted = CGPreflightListenEventAccess()
            }
        }
    }

    private func openPrivacySettings(for pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    private var previewText: String {
        var parts: [String] = []
        if useControl { parts.append("⌃") }
        if useOption { parts.append("⌥") }
        if useShift { parts.append("⇧") }
        if useCommand { parts.append("⌘") }

        let triggerLabel: String
        if triggerType == .keyboard {
            triggerLabel = Self.availableKeys.first { $0.value == selectedKey }?.label ?? selectedKey.capitalized
        } else {
            triggerLabel = Self.mouseButtons.first { $0.value == selectedMouseButton }?.label ?? selectedMouseButton
        }
        parts.append(triggerLabel)

        return parts.joined(separator: " + ")
    }

    private func loadFromConfig() {
        let config = configManager.config
        let hotkey = config.hotkey
        triggerType = hotkey.isMouseTrigger ? .mouse : .keyboard
        selectedMouseButton = hotkey.key
        selectedKey = hotkey.key
        useCommand = hotkey.modifiers.contains("command")
        useShift = hotkey.modifiers.contains("shift")
        useOption = hotkey.modifiers.contains("option")
        useControl = hotkey.modifiers.contains("control")

        // Pad or trim sectors to match sectorCount
        let count = config.sectorCount
        var loaded = config.sectors
        while loaded.count < count { loaded.append(.recent(index: loaded.count)) }
        sectorConfigs = Array(loaded.prefix(count))

        installedApps = InstalledAppsFinder.findAll()
    }

    private func save() {
        let key = triggerType == .keyboard ? selectedKey : selectedMouseButton
        let type = triggerType == .keyboard ? "keyboard" : "mouse"

        var modifiers: [String] = []
        if useControl { modifiers.append("control") }
        if useOption { modifiers.append("option") }
        if useShift { modifiers.append("shift") }
        if useCommand { modifiers.append("command") }

        configManager.config.hotkey = OrbitConfig.HotkeyConfig(type: type, key: key, modifiers: modifiers)

        // Re-number recent indices sequentially
        var recentIdx = 0
        configManager.config.sectors = sectorConfigs.map { sector in
            switch sector {
            case .recent:
                defer { recentIdx += 1 }
                return .recent(index: recentIdx)
            case .pinned:
                return sector
            }
        }

        configManager.saveConfig()
        onSave()
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    let accessibilityGranted: Bool
    let inputMonitoringGranted: Bool
    let allPermissionsGranted: Bool
    @Binding var triggerType: SettingsView.TriggerType
    @Binding var selectedKey: String
    @Binding var selectedMouseButton: String
    @Binding var useControl: Bool
    @Binding var useOption: Bool
    @Binding var useShift: Bool
    @Binding var useCommand: Bool
    let previewText: String
    let openPrivacySettings: (String) -> Void

    var body: some View {
        Form {
            Section {
                PermissionRow(
                    title: "Accessibility Access",
                    description: "Required to intercept the hotkey and prevent other apps from receiving it.",
                    isGranted: accessibilityGranted,
                    openSettings: { openPrivacySettings("Privacy_Accessibility") }
                )

                PermissionRow(
                    title: "Input Monitoring",
                    description: "Required to detect global keyboard and mouse events for the hotkey.",
                    isGranted: inputMonitoringGranted,
                    openSettings: {
                        CGRequestListenEventAccess()
                        openPrivacySettings("Privacy_ListenEvent")
                    }
                )
            } header: {
                Text("System Permissions")
            } footer: {
                if !allPermissionsGranted {
                    Label(
                        "Orbit requires these permissions to function correctly. Grant access in System Settings.",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                }
            }

            Section("Activation Hotkey") {
                Picker("Trigger Type", selection: $triggerType.animation()) {
                    ForEach(SettingsView.TriggerType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                if triggerType == .keyboard {
                    Picker("Key", selection: $selectedKey) {
                        ForEach(SettingsView.availableKeys, id: \.value) { key in
                            Text(key.label).tag(key.value)
                        }
                    }
                } else {
                    Picker("Mouse Button", selection: $selectedMouseButton) {
                        ForEach(SettingsView.mouseButtons, id: \.value) { btn in
                            Text(btn.label).tag(btn.value)
                        }
                    }
                }

                LabeledContent {
                    HStack(spacing: 4) {
                        ModifierToggle("⌃", isOn: $useControl)
                        ModifierToggle("⌥", isOn: $useOption)
                        ModifierToggle("⇧", isOn: $useShift)
                        ModifierToggle("⌘", isOn: $useCommand)
                    }
                } label: {
                    Text("Modifiers")
                }

                // Inline hotkey preview
                LabeledContent {
                    Text(previewText)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .secondarySystemFill), in: RoundedRectangle(cornerRadius: 5))
                } label: {
                    Text("Preview")
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

// MARK: - Modifier Toggle

private struct ModifierToggle: View {
    let label: String
    @Binding var isOn: Bool

    init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        self._isOn = isOn
    }

    var body: some View {
        Toggle(label, isOn: $isOn)
            .toggleStyle(.button)
            .controlSize(.regular)
            .font(.system(.body, design: .monospaced))
            .frame(width: 34)
    }
}

// MARK: - Sectors Tab

private struct SectorsTab: View {
    @Binding var sectorConfigs: [OrbitConfig.SectorConfig]
    @Binding var selectedSectorIndex: Int
    @Binding var showingAppPicker: Bool
    let installedApps: [InstalledApp]

    var body: some View {
        Form {
            Section {
                SectorRingPreview(
                    configs: sectorConfigs,
                    selectedIndex: $selectedSectorIndex,
                    installedApps: installedApps
                )
                .padding(.vertical, 4)
            }

            Section("Sector Configuration") {
                SectorEditor(
                    config: $sectorConfigs[selectedSectorIndex],
                    index: selectedSectorIndex,
                    installedApps: installedApps,
                    onChooseApp: { showingAppPicker = true }
                )
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

// MARK: - Sector Ring Preview

private struct SectorRingPreview: View {
    let configs: [OrbitConfig.SectorConfig]
    @Binding var selectedIndex: Int
    let installedApps: [InstalledApp]

    private let ringRadius: CGFloat = 80
    private let dotSize: CGFloat = 42

    var body: some View {
        HStack {
            Spacer()
            ZStack {
                // Subtle connecting ring
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                    .frame(width: ringRadius * 2, height: ringRadius * 2)

                ForEach(configs.indices, id: \.self) { i in
                    let angle = angleFor(index: i, total: configs.count)
                    let x = cos(angle) * ringRadius
                    let y = sin(angle) * ringRadius
                    let isSelected = i == selectedIndex

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedIndex = i
                        }
                    } label: {
                        sectorIcon(for: configs[i])
                            .frame(width: dotSize, height: dotSize)
                            .background(.regularMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        isSelected ? Color.accentColor : Color.secondary.opacity(0.15),
                                        lineWidth: isSelected ? 1.5 : 0.5
                                    )
                            )
                            .scaleEffect(isSelected ? 1.08 : 1.0)
                            .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : .clear, radius: 4)
                    }
                    .buttonStyle(.plain)
                    .offset(x: x, y: y)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedIndex)
                }

                // Center label
                VStack(spacing: 0) {
                    Text("SECTOR")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                    Text("\(selectedIndex + 1)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: ringRadius * 2 + dotSize + 8, height: ringRadius * 2 + dotSize + 8)
            Spacer()
        }
    }

    private func angleFor(index: Int, total: Int) -> CGFloat {
        let step = (2 * .pi) / CGFloat(total)
        return -.pi / 2 + step * CGFloat(index)
    }

    @ViewBuilder
    private func sectorIcon(for config: OrbitConfig.SectorConfig) -> some View {
        switch config {
        case .recent:
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        case .pinned(let bundleId, _, _):
            if let app = installedApps.first(where: { $0.bundleId == bundleId }) {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(5)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Sector Editor

private struct SectorEditor: View {
    @Binding var config: OrbitConfig.SectorConfig
    let index: Int
    let installedApps: [InstalledApp]
    let onChooseApp: () -> Void

    private var isPinned: Binding<Bool> {
        Binding(
            get: {
                if case .pinned = config { return true }
                return false
            },
            set: { pinned in
                withAnimation {
                    if pinned {
                        config = .pinned(bundleId: "", name: "", icon: nil)
                    } else {
                        config = .recent(index: 0)
                    }
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Type", selection: isPinned) {
                Text("Recent App").tag(false)
                Text("Pinned App").tag(true)
            }
            .pickerStyle(.segmented)

            if case .pinned(let bundleId, let name, _) = config {
                HStack(spacing: 10) {
                    if let app = installedApps.first(where: { $0.bundleId == bundleId }) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(app.name)
                                .lineLimit(1)
                            Text(app.bundleId)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Change...") { onChooseApp() }
                            .controlSize(.small)
                    } else if !name.isEmpty {
                        Image(systemName: "app.dashed")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(name)
                                .lineLimit(1)
                            Text(bundleId)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Change...") { onChooseApp() }
                            .controlSize(.small)
                    } else {
                        Button("Choose App...", action: onChooseApp)
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                Text("Shows the next most recently used app.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let openSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(isGranted ? .green : .orange)
                .frame(width: 26)
                .symbolRenderingMode(.hierarchical)
                .contentTransition(.symbolEffect(.replace))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if !isGranted {
                Button("Grant Access") { openSettings() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.25), value: isGranted)
    }
}
