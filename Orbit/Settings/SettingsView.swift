import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    let configManager: ConfigManager
    let onSave: () -> Void

    @State private var accessibilityGranted = HotkeyManager.hasPermission()
    @State private var inputMonitoringGranted = CGPreflightListenEventAccess()

    @State private var hotkeyKey: String = "mouse4"
    @State private var hotkeyType: String = "mouse"
    @State private var hotkeyModifiers: [String] = []

    @State private var sectorConfigs: [OrbitConfig.SectorConfig] = (0..<8).map { .recent(index: $0) }
    @State private var selectedSectorIndex: Int = 0
    @State private var showingAppPicker = false
    @State private var showingPathPicker = false
    @State private var installedApps: [InstalledApp] = []

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var allPermissionsGranted: Bool {
        accessibilityGranted && inputMonitoringGranted
    }

    private var hotkeyDisplayText: String {
        KeyCombo(key: hotkeyKey, modifiers: hotkeyModifiers).displayName
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                GeneralTab(
                    accessibilityGranted: accessibilityGranted,
                    inputMonitoringGranted: inputMonitoringGranted,
                    allPermissionsGranted: allPermissionsGranted,
                    hotkeyKey: $hotkeyKey,
                    hotkeyType: $hotkeyType,
                    hotkeyModifiers: $hotkeyModifiers,
                    hotkeyDisplayText: hotkeyDisplayText,
                    openPrivacySettings: openPrivacySettings
                )
                .tabItem { Label("General", systemImage: "gearshape") }

                SectorsTab(
                    sectorConfigs: $sectorConfigs,
                    selectedSectorIndex: $selectedSectorIndex,
                    showingAppPicker: $showingAppPicker,
                    showingPathPicker: $showingPathPicker,
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
                .buttonStyle(.glassProminent)
                .tint(.accentColor)
                .controlSize(.regular)
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator), alignment: .top)
        }
        .frame(width: 640, height: 560)
        .background(.regularMaterial)
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(apps: installedApps) { app in
                sectorConfigs[selectedSectorIndex] = .pinned(
                    bundleId: app.bundleId,
                    name: app.name,
                    icon: nil
                )
            }
        }
        .onChange(of: showingPathPicker) { _, show in
            guard show else { return }
            showingPathPicker = false
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.message = "Choose a file or folder to open"
            if panel.runModal() == .OK, let url = panel.url {
                let name: String
                if case .openPath(let existingName, _, _) = sectorConfigs[selectedSectorIndex], !existingName.isEmpty {
                    name = existingName
                } else {
                    name = url.lastPathComponent
                }
                sectorConfigs[selectedSectorIndex] = .openPath(
                    name: name,
                    path: url.path,
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

    private func loadFromConfig() {
        let config = configManager.config
        let hotkey = config.hotkey
        hotkeyKey = hotkey.key
        hotkeyType = hotkey.isMouseTrigger ? "mouse" : "keyboard"
        hotkeyModifiers = hotkey.modifiers

        // Pad or trim sectors to match sectorCount
        let count = config.sectorCount
        var loaded = config.sectors
        while loaded.count < count { loaded.append(.recent(index: loaded.count)) }
        sectorConfigs = Array(loaded.prefix(count))

        installedApps = InstalledAppsFinder.findAll()
    }

    private func save() {
        configManager.config.hotkey = OrbitConfig.HotkeyConfig(type: hotkeyType, key: hotkeyKey, modifiers: hotkeyModifiers)

        // Re-number recent indices sequentially; pass through all other types
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
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    let accessibilityGranted: Bool
    let inputMonitoringGranted: Bool
    let allPermissionsGranted: Bool
    @Binding var hotkeyKey: String
    @Binding var hotkeyType: String
    @Binding var hotkeyModifiers: [String]
    let hotkeyDisplayText: String
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

            Section {
                HotkeyRecorderRow(
                    key: $hotkeyKey,
                    type: $hotkeyType,
                    modifiers: $hotkeyModifiers,
                    displayText: hotkeyDisplayText
                )
            } header: {
                Text("Activation Hotkey")
            } footer: {
                Text("Click \"Record\" and press any key or mouse button combination.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

// MARK: - Hotkey Recorder

private struct HotkeyRecorderRow: View {
    @Binding var key: String
    @Binding var type: String
    @Binding var modifiers: [String]
    let displayText: String

    @State private var isRecording = false

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Text(isRecording ? "Press a key..." : displayText)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(isRecording ? .secondary : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(minWidth: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isRecording ? Color.accentColor.opacity(0.1) : Color(nsColor: .secondarySystemFill))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    )

                if isRecording {
                    Button("Cancel") {
                        isRecording = false
                    }
                    .controlSize(.small)
                } else {
                    Button("Record") {
                        isRecording = true
                    }
                    .controlSize(.small)
                }
            }
        } label: {
            Text("Hotkey")
        }
        .background {
            if isRecording {
                HotkeyRecorderHelper(
                    onKeyRecorded: { newKey, newModifiers in
                        key = newKey
                        type = newKey.hasPrefix("mouse") ? "mouse" : "keyboard"
                        modifiers = newModifiers
                        isRecording = false
                    },
                    onCancel: {
                        isRecording = false
                    }
                )
            }
        }
    }
}

// MARK: - NSView-based Hotkey Recorder Helper

private struct HotkeyRecorderHelper: NSViewRepresentable {
    let onKeyRecorded: (String, [String]) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onKeyRecorded = onKeyRecorded
        view.onCancel = onCancel
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.onKeyRecorded = onKeyRecorded
        nsView.onCancel = onCancel
    }
}

private final class HotkeyRecorderNSView: NSView {
    var onKeyRecorded: ((String, [String]) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Escape cancels recording
        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }

        let keyName = Self.keyName(for: Int64(event.keyCode))
        guard let keyName else { return }

        let mods = Self.modifierNames(from: event.modifierFlags)
        onKeyRecorded?(keyName, mods)
    }

    override func otherMouseDown(with event: NSEvent) {
        let buttonNumber = event.buttonNumber
        let mouseName: String
        switch buttonNumber {
        case 2: mouseName = "mouse3"
        case 3: mouseName = "mouse4"
        case 4: mouseName = "mouse5"
        default: mouseName = "mouse\(buttonNumber + 1)"
        }
        let mods = Self.modifierNames(from: event.modifierFlags)
        onKeyRecorded?(mouseName, mods)
    }

    private static func keyName(for keyCode: Int64) -> String? {
        return KeyCombo.keyNames[keyCode]
    }

    private static func modifierNames(from flags: NSEvent.ModifierFlags) -> [String] {
        var mods: [String] = []
        if flags.contains(.control) { mods.append("control") }
        if flags.contains(.option) { mods.append("option") }
        if flags.contains(.shift) { mods.append("shift") }
        if flags.contains(.command) { mods.append("command") }
        return mods
    }
}

// MARK: - Sectors Tab

private struct SectorsTab: View {
    @Binding var sectorConfigs: [OrbitConfig.SectorConfig]
    @Binding var selectedSectorIndex: Int
    @Binding var showingAppPicker: Bool
    @Binding var showingPathPicker: Bool
    let installedApps: [InstalledApp]

    var body: some View {
        HStack(spacing: 0) {
            // Left: ring slots
            VStack(alignment: .leading, spacing: 4) {
                Text("Ring Slots")
                    .font(.title3.bold())
                Text("Click a slot to configure it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SectorRingPreview(
                    configs: sectorConfigs,
                    selectedIndex: $selectedSectorIndex,
                    installedApps: installedApps
                )
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .frame(width: 280)

            Divider()

            // Right: editor
            SectorEditorPanel(
                config: $sectorConfigs[selectedSectorIndex],
                index: selectedSectorIndex,
                installedApps: installedApps,
                onChooseApp: { showingAppPicker = true },
                onBrowsePath: { showingPathPicker = true }
            )
        }
    }
}

// MARK: - Sector Ring Preview

private struct SectorRingPreview: View {
    let configs: [OrbitConfig.SectorConfig]
    @Binding var selectedIndex: Int
    let installedApps: [InstalledApp]

    private let ringRadius: CGFloat = 80
    private let slotSize: CGFloat = 40

    var body: some View {
        ZStack {
            // Connecting ring — ellipse fill
            Circle()
                .fill(Color.secondary.opacity(0.04))
                .frame(width: ringRadius * 2 + slotSize, height: ringRadius * 2 + slotSize)
            Circle()
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                .frame(width: ringRadius * 2 + slotSize, height: ringRadius * 2 + slotSize)

            ForEach(configs.indices, id: \.self) { i in
                let angle = angleFor(index: i, total: configs.count)
                let x = cos(angle) * ringRadius
                let y = sin(angle) * ringRadius
                let isSelected = i == selectedIndex

                Button {
                    selectedIndex = i
                } label: {
                    sectorIcon(for: configs[i])
                        .frame(width: slotSize, height: slotSize)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .shadow(color: .black.opacity(0.1), radius: 1.5, y: 0.5)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: isSelected ? 2 : 0.5)
                        )
                }
                .buttonStyle(.plain)
                .offset(x: x, y: y)
            }
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
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        case .pinned(let bundleId, _, _):
            if let app = installedApps.first(where: { $0.bundleId == bundleId }) {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
        case .url:
            Image(systemName: "globe")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        case .shellCommand:
            Image(systemName: "terminal.fill")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        case .systemAction(let kind):
            Image(systemName: kind.sfSymbolName)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        case .shortcut:
            Image(systemName: "command.square.fill")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        case .openPath:
            Image(systemName: "folder.fill")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        case .translate:
            Image(systemName: "translate")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Right Panel Editor

private struct SectorEditorPanel: View {
    @Binding var config: OrbitConfig.SectorConfig
    let index: Int
    let installedApps: [InstalledApp]
    let onChooseApp: () -> Void
    let onBrowsePath: () -> Void

    @State private var searchText = ""

    private var sectorKind: Binding<SectorKind> {
        Binding(
            get: { SectorKind(from: config) },
            set: { kind in
                switch kind {
                case .recent: config = .recent(index: 0)
                case .pinned: config = .pinned(bundleId: "", name: "", icon: nil)
                case .url: config = .url(name: "", url: "", icon: nil)
                case .shellCommand: config = .shellCommand(name: "", command: "", icon: nil)
                case .systemAction: config = .systemAction(action: .lockScreen)
                case .shortcut: config = .shortcut(name: "")
                case .openPath: config = .openPath(name: "", path: "", icon: nil)
                case .translate: config = .translate
                }
            }
        )
    }

    private var filteredApps: [InstalledApp] {
        guard !searchText.isEmpty else { return installedApps }
        let q = searchText.lowercased()
        return installedApps.filter {
            $0.name.lowercased().contains(q) || $0.bundleId.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Sector \(index + 1)")
                    .font(.title3.bold())
                Spacer()
                Picker("", selection: sectorKind) {
                    ForEach(SectorKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider()

            // Content
            sectorContent
        }
    }

    @ViewBuilder
    private var sectorContent: some View {
        switch config {
        case .pinned:
            appGridView

        default:
            Form {
                sectorFields
            }
            .formStyle(.grouped)
        }
    }

    private var selectedBundleId: String? {
        if case .pinned(let bid, _, _) = config { return bid }
        return nil
    }

    private var appGridView: some View {
        VStack(spacing: 0) {
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            List {
                ForEach(filteredApps) { app in
                    appRow(app: app, isSelected: selectedBundleId == app.bundleId)
                }
            }
            .listStyle(.plain)
        }
    }

    private func appRow(app: InstalledApp, isSelected: Bool) -> some View {
        Button {
            config = .pinned(bundleId: app.bundleId, name: app.name, icon: nil)
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                Text(app.name)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    @ViewBuilder
    private var sectorFields: some View {
        switch config {
        case .recent:
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automatic")
                            .fontWeight(.medium)
                        Text("Shows the most recently used application. No configuration needed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }

        case .url(let name, let url, _):
            Section {
                TextField("Display Name", text: urlNameBinding(name: name, url: url), prompt: Text("e.g. GitHub"))
                TextField("URL", text: urlValueBinding(name: name, url: url), prompt: Text("https://example.com"))
                    .textContentType(.URL)
            } header: {
                Text("URL")
            } footer: {
                if !url.isEmpty, URL(string: url) == nil {
                    Label("Invalid URL format.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Text("Opens in your default browser.")
                }
            }

        case .shellCommand(let name, let command, _):
            Section {
                TextField("Display Name", text: shellNameBinding(name: name, command: command), prompt: Text("e.g. Build Project"))
                TextField("Command", text: shellCommandBinding(name: name, command: command), prompt: Text("e.g. make build && say done"))
                    .font(.system(.body, design: .monospaced))
            } header: {
                Text("Shell Command")
            } footer: {
                Text("Runs via /bin/zsh. Output is silenced.")
            }

        case .systemAction(let action):
            Section {
                Picker("Action", selection: systemActionBinding(current: action)) {
                    ForEach(OrbitConfig.SystemActionKind.allCases, id: \.self) { kind in
                        Label(kind.displayName, systemImage: kind.sfSymbolName).tag(kind)
                    }
                }
            } header: {
                Text("System Action")
            } footer: {
                Label(systemActionDescription(action), systemImage: action.sfSymbolName)
            }

        case .shortcut(let name):
            Section {
                TextField("Shortcut Name", text: shortcutNameBinding(name: name), prompt: Text("e.g. Toggle Focus Mode"))
            } header: {
                Text("Shortcut")
            } footer: {
                Text("Enter the exact name from the Shortcuts app.")
            }

        case .openPath(let name, let path, _):
            Section {
                TextField("Display Name", text: pathNameBinding(name: name, path: path), prompt: Text("e.g. Downloads"))
                HStack {
                    TextField("Path", text: pathValueBinding(name: name, path: path), prompt: Text("~/Documents"))
                        .font(.system(.body, design: .monospaced))
                    Button("Browse...", action: onBrowsePath)
                }
            } header: {
                Text("File or Folder")
            } footer: {
                if !path.isEmpty {
                    let expanded = NSString(string: path).expandingTildeInPath
                    let exists = FileManager.default.fileExists(atPath: expanded)
                    Label(
                        exists ? "Path exists." : "Path not found.",
                        systemImage: exists ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(exists ? .green : .orange)
                } else {
                    Text("Opens in Finder. Supports ~ for home directory.")
                }
            }

        case .translate:
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Translate Selected Text")
                            .fontWeight(.medium)
                        Text("Translates the currently selected text. Chinese ↔ English auto-detected.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "translate")
                }
            }

        default:
            EmptyView()
        }
    }

    private func systemActionDescription(_ action: OrbitConfig.SystemActionKind) -> String {
        switch action {
        case .lockScreen: "Puts the display to sleep and locks the screen."
        case .toggleDnd: "Toggles Do Not Disturb via the Shortcuts app."
        case .screenshot: "Opens interactive screenshot capture."
        case .sleepDisplay: "Turns off the display immediately."
        case .emptyTrash: "Empties the Trash via Finder."
        }
    }

    // MARK: - Field Bindings

    private func urlNameBinding(name: String, url: String) -> Binding<String> {
        Binding(get: { name }, set: { config = .url(name: $0, url: url, icon: nil) })
    }

    private func urlValueBinding(name: String, url: String) -> Binding<String> {
        Binding(get: { url }, set: { config = .url(name: name, url: $0, icon: nil) })
    }

    private func shellNameBinding(name: String, command: String) -> Binding<String> {
        Binding(get: { name }, set: { config = .shellCommand(name: $0, command: command, icon: nil) })
    }

    private func shellCommandBinding(name: String, command: String) -> Binding<String> {
        Binding(get: { command }, set: { config = .shellCommand(name: name, command: $0, icon: nil) })
    }

    private func systemActionBinding(current: OrbitConfig.SystemActionKind) -> Binding<OrbitConfig.SystemActionKind> {
        Binding(get: { current }, set: { config = .systemAction(action: $0) })
    }

    private func shortcutNameBinding(name: String) -> Binding<String> {
        Binding(get: { name }, set: { config = .shortcut(name: $0) })
    }

    private func pathNameBinding(name: String, path: String) -> Binding<String> {
        Binding(get: { name }, set: { config = .openPath(name: $0, path: path, icon: nil) })
    }

    private func pathValueBinding(name: String, path: String) -> Binding<String> {
        Binding(get: { path }, set: { config = .openPath(name: name, path: $0, icon: nil) })
    }
}

private enum SectorKind: String, CaseIterable {
    case recent = "Recent App"
    case pinned = "Open App"
    case url = "URL"
    case shellCommand = "Shell Command"
    case systemAction = "System Action"
    case shortcut = "Shortcut"
    case openPath = "File or Folder"
    case translate = "Translate"

    init(from config: OrbitConfig.SectorConfig) {
        switch config {
        case .recent: self = .recent
        case .pinned: self = .pinned
        case .url: self = .url
        case .shellCommand: self = .shellCommand
        case .systemAction: self = .systemAction
        case .shortcut: self = .shortcut
        case .openPath: self = .openPath
        case .translate: self = .translate
        }
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
