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

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var allPermissionsGranted: Bool {
        accessibilityGranted && inputMonitoringGranted
    }

    enum TriggerType: String, CaseIterable {
        case keyboard = "Keyboard"
        case mouse = "Mouse Button"
    }

    private static let availableKeys: [(label: String, value: String)] = [
        ("Space", "space"),
        ("Return", "return"),
        ("Tab", "tab"),
        ("Escape", "escape"),
    ] + (UnicodeScalar("a").value...UnicodeScalar("z").value).map { scalar in
        let ch = String(UnicodeScalar(scalar)!)
        return (ch.uppercased(), ch)
    }

    private static let mouseButtons: [(label: String, value: String)] = [
        ("Mouse 3 (Middle)", "mouse3"),
        ("Mouse 4 (Back)", "mouse4"),
        ("Mouse 5 (Forward)", "mouse5"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Permissions
            VStack(alignment: .leading, spacing: 12) {
                Text("Permissions")
                    .font(.title3.bold())

                PermissionRow(
                    title: "Accessibility",
                    description: "Intercept hotkey to prevent other apps from receiving it",
                    isGranted: accessibilityGranted
                ) {
                    HotkeyManager.requestPermission()
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }

                PermissionRow(
                    title: "Input Monitoring",
                    description: "Detect global keyboard and mouse button events",
                    isGranted: inputMonitoringGranted
                ) {
                    CGRequestListenEventAccess()
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .padding(20)

            Divider()

            // MARK: - Hotkey Settings
            VStack(alignment: .leading, spacing: 14) {
                Text("Hotkey")
                    .font(.title3.bold())

                Picker("Trigger Type", selection: $triggerType) {
                    ForEach(TriggerType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                if triggerType == .keyboard {
                    Picker("Key", selection: $selectedKey) {
                        ForEach(Self.availableKeys, id: \.value) { key in
                            Text(key.label).tag(key.value)
                        }
                    }
                } else {
                    Picker("Mouse Button", selection: $selectedMouseButton) {
                        ForEach(Self.mouseButtons, id: \.value) { btn in
                            Text(btn.label).tag(btn.value)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Modifiers")
                        .font(.subheadline.bold())
                    HStack(spacing: 16) {
                        Toggle("Ctrl", isOn: $useControl)
                        Toggle("Opt", isOn: $useOption)
                        Toggle("Shift", isOn: $useShift)
                        Toggle("Cmd", isOn: $useCommand)
                    }
                    .toggleStyle(.checkbox)
                }

                Divider()

                HStack {
                    Text("Current:")
                        .foregroundStyle(.secondary)
                    Text(previewText)
                        .font(.system(.body, design: .monospaced).bold())
                    Spacer()
                    Button("Save") {
                        save()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
        .frame(width: 400)
        .onAppear { loadFromConfig() }
        .onReceive(timer) { _ in
            accessibilityGranted = HotkeyManager.hasPermission()
            inputMonitoringGranted = CGPreflightListenEventAccess()
        }
    }

    private var previewText: String {
        var parts: [String] = []
        if useControl { parts.append("Ctrl") }
        if useOption { parts.append("Opt") }
        if useShift { parts.append("Shift") }
        if useCommand { parts.append("Cmd") }

        if triggerType == .keyboard {
            parts.append(selectedKey.capitalized)
        } else {
            let label = Self.mouseButtons.first { $0.value == selectedMouseButton }?.label ?? selectedMouseButton
            parts.append(label)
        }
        return parts.joined(separator: "+")
    }

    private func loadFromConfig() {
        let hotkey = configManager.config.hotkey
        if hotkey.isMouseTrigger {
            triggerType = .mouse
            selectedMouseButton = hotkey.key
        } else {
            triggerType = .keyboard
            selectedKey = hotkey.key
        }
        useCommand = hotkey.modifiers.contains("command")
        useShift = hotkey.modifiers.contains("shift")
        useOption = hotkey.modifiers.contains("option")
        useControl = hotkey.modifiers.contains("control")
    }

    private func save() {
        var modifiers: [String] = []
        if useControl { modifiers.append("control") }
        if useOption { modifiers.append("option") }
        if useShift { modifiers.append("shift") }
        if useCommand { modifiers.append("command") }

        let key: String
        let type: String
        if triggerType == .keyboard {
            key = selectedKey
            type = "keyboard"
        } else {
            key = selectedMouseButton
            type = "mouse"
        }

        configManager.config.hotkey = OrbitConfig.HotkeyConfig(
            type: type,
            key: key,
            modifiers: modifiers
        )
        configManager.saveConfig()
        onSave()
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(isGranted ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isGranted {
                Button("Grant") {
                    openSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isGranted)
    }
}
