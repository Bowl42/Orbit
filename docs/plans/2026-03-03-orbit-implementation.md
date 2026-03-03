# Orbit Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS native radial shortcut menu app that appears on hotkey hold, selects via mouse direction, and executes on release.

**Architecture:** NSPanel floating overlay with SwiftUI content, global hotkey via CGEvent tap (.listenOnly + Input Monitoring permission), menu bar app with no Dock icon. Config stored as JSON.

**Tech Stack:** Swift, SwiftUI, AppKit (NSPanel, NSVisualEffectView, NSWorkspace, CGEvent), macOS 15+

---

### Task 1: Create Xcode Project Skeleton

**Files:**
- Create: `Orbit/OrbitApp.swift`
- Create: `Orbit/AppDelegate.swift`
- Create: `Orbit/Info.plist`
- Create: `Orbit/Orbit.entitlements`
- Create: `Orbit.xcodeproj` (via `xcodebuild` or manual)
- Create: `Package.swift` (Swift Package for build)

Since we're building from an empty directory without Xcode GUI, we'll use a Swift Package with an executable target that builds as a macOS app bundle.

**Step 1: Create the Swift Package structure**

Create `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Orbit",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Orbit",
            path: "Orbit",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        )
    ]
)
```

Create directory structure:

```bash
mkdir -p Orbit/Resources
```

**Step 2: Create the minimal app entry point**

Create `Orbit/OrbitApp.swift`:

```swift
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
```

Create `Orbit/AppDelegate.swift`:

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
```

Create `Orbit/Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleName</key>
    <string>Orbit</string>
    <key>CFBundleDisplayName</key>
    <string>Orbit</string>
    <key>CFBundleIdentifier</key>
    <string>com.bowl42.Orbit</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
</dict>
</plist>
```

**Step 3: Verify it builds**

Run: `swift build`
Expected: Successful build with no errors.

**Step 4: Verify it runs as a menu bar app**

Run: `swift run`
Expected: Orbit icon appears in menu bar. Clicking shows "Orbit" text and Quit button. No Dock icon.

**Step 5: Commit**

```bash
git add Package.swift Orbit/
git commit -m "feat: initial project skeleton with menu bar app"
```

---

### Task 2: Configuration Model & Manager

**Files:**
- Create: `Orbit/Config/OrbitConfig.swift`
- Create: `Orbit/Config/ConfigManager.swift`

**Step 1: Create the configuration model**

Create `Orbit/Config/OrbitConfig.swift`:

```swift
import Foundation

struct OrbitConfig: Codable, Equatable {
    var hotkey: HotkeyConfig
    var sectorCount: Int
    var sectors: [SectorConfig]

    struct HotkeyConfig: Codable, Equatable {
        var key: String          // e.g. "space"
        var modifiers: [String]  // e.g. ["control"]
    }

    enum SectorConfig: Codable, Equatable {
        case recent(index: Int)
        case pinned(bundleId: String, name: String, icon: IconConfig?)

        enum CodingKeys: String, CodingKey {
            case type, index, bundleId, name, icon
        }

        struct IconConfig: Codable, Equatable {
            var sfSymbol: String?
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "recent":
                let index = try container.decode(Int.self, forKey: .index)
                self = .recent(index: index)
            case "pinned":
                let bundleId = try container.decode(String.self, forKey: .bundleId)
                let name = try container.decode(String.self, forKey: .name)
                let icon = try container.decodeIfPresent(IconConfig.self, forKey: .icon)
                self = .pinned(bundleId: bundleId, name: name, icon: icon)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type, in: container,
                    debugDescription: "Unknown sector type: \(type)"
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .recent(let index):
                try container.encode("recent", forKey: .type)
                try container.encode(index, forKey: .index)
            case .pinned(let bundleId, let name, let icon):
                try container.encode("pinned", forKey: .type)
                try container.encode(bundleId, forKey: .bundleId)
                try container.encode(name, forKey: .name)
                try container.encodeIfPresent(icon, forKey: .icon)
            }
        }
    }

    static let `default` = OrbitConfig(
        hotkey: HotkeyConfig(key: "space", modifiers: ["control"]),
        sectorCount: 8,
        sectors: (0..<8).map { .recent(index: $0) }
    )
}
```

**Step 2: Create the config manager**

Create `Orbit/Config/ConfigManager.swift`:

```swift
import Foundation

@Observable
final class ConfigManager {
    var config: OrbitConfig

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("Orbit", isDirectory: true)

        self.fileURL = appSupport.appendingPathComponent("config.json")
        self.config = .default

        loadConfig()
    }

    func loadConfig() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            saveConfig()  // Write default on first run
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            config = try decoder.decode(OrbitConfig.self, from: data)
        } catch {
            print("Failed to load config, using defaults: \(error)")
            config = .default
        }
    }

    func saveConfig() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save config: \(error)")
        }
    }
}
```

**Step 3: Verify it builds**

Run: `swift build`
Expected: Successful build.

**Step 4: Commit**

```bash
git add Orbit/Config/
git commit -m "feat: add config model and JSON config manager"
```

---

### Task 3: Recent Apps Tracker

**Files:**
- Create: `Orbit/RecentApps/RecentAppsTracker.swift`

**Step 1: Create the recent apps tracker**

Create `Orbit/RecentApps/RecentAppsTracker.swift`:

```swift
import AppKit
import Combine

@Observable
final class RecentAppsTracker {
    var recentApps: [AppInfo] = []
    let maxRecent: Int

    private var cancellable: AnyCancellable?
    private let selfBundleID = Bundle.main.bundleIdentifier

    struct AppInfo: Identifiable, Equatable, Hashable {
        let id: String  // bundleIdentifier
        let name: String
        let icon: NSImage

        static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    init(maxRecent: Int = 20) {
        self.maxRecent = maxRecent

        cancellable = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { notification -> NSRunningApplication? in
                notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] app in
                self?.handleAppActivation(app)
            }

        seedWithRunningApps()
    }

    private func handleAppActivation(_ app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier,
              bundleID != selfBundleID,
              bundleID != "com.apple.finder",
              app.activationPolicy == .regular
        else { return }

        let name = app.localizedName ?? bundleID
        let icon = app.icon ?? NSWorkspace.shared.icon(forFile: "/Applications")

        let info = AppInfo(id: bundleID, name: name, icon: icon)

        recentApps.removeAll { $0.id == bundleID }
        recentApps.insert(info, at: 0)

        if recentApps.count > maxRecent {
            recentApps = Array(recentApps.prefix(maxRecent))
        }
    }

    func seedWithRunningApps() {
        let running = NSWorkspace.shared.runningApplications
            .filter {
                $0.activationPolicy == .regular
                && $0.bundleIdentifier != selfBundleID
                && $0.bundleIdentifier != "com.apple.finder"
            }

        for app in running {
            guard let bundleID = app.bundleIdentifier else { continue }
            if recentApps.contains(where: { $0.id == bundleID }) { continue }

            let name = app.localizedName ?? bundleID
            let icon = app.icon ?? NSWorkspace.shared.icon(forFile: "/Applications")
            recentApps.append(AppInfo(id: bundleID, name: name, icon: icon))
        }
    }

    /// Returns up to `count` recent apps for filling radial menu sectors.
    func topRecent(_ count: Int) -> [AppInfo] {
        Array(recentApps.prefix(count))
    }
}
```

**Step 2: Verify it builds**

Run: `swift build`
Expected: Successful build.

**Step 3: Commit**

```bash
git add Orbit/RecentApps/
git commit -m "feat: add recent apps tracker using NSWorkspace notifications"
```

---

### Task 4: Action System

**Files:**
- Create: `Orbit/Actions/OrbitAction.swift`
- Create: `Orbit/Actions/LaunchAppAction.swift`

**Step 1: Create action protocol and types**

Create `Orbit/Actions/OrbitAction.swift`:

```swift
import AppKit

enum ActionIcon {
    case appIcon(bundleId: String)
    case sfSymbol(name: String)

    var nsImage: NSImage? {
        switch self {
        case .appIcon(let bundleId):
            guard let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleId
            ) else { return nil }
            return NSWorkspace.shared.icon(forFile: url.path)
        case .sfSymbol(let name):
            return NSImage(systemSymbolName: name, accessibilityDescription: nil)
        }
    }
}

protocol OrbitAction {
    var id: String { get }
    var name: String { get }
    var icon: ActionIcon { get }
    var subtitle: String? { get }
    func execute() async
}
```

Create `Orbit/Actions/LaunchAppAction.swift`:

```swift
import AppKit

struct LaunchAppAction: OrbitAction {
    let id: String
    let name: String
    let bundleIdentifier: String
    var subtitle: String? { nil }

    var icon: ActionIcon {
        .appIcon(bundleId: bundleIdentifier)
    }

    func execute() async {
        // Try activating first if already running
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        )
        if let app = running.first {
            await MainActor.run {
                app.activate()
            }
            return
        }

        // Otherwise launch
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else {
            print("App not found: \(bundleIdentifier)")
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        do {
            try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
        } catch {
            print("Failed to launch \(bundleIdentifier): \(error)")
        }
    }
}
```

**Step 2: Verify it builds**

Run: `swift build`
Expected: Successful build.

**Step 3: Commit**

```bash
git add Orbit/Actions/
git commit -m "feat: add action protocol and LaunchAppAction"
```

---

### Task 5: Radial Menu Panel (NSPanel)

**Files:**
- Create: `Orbit/RadialMenu/RadialMenuPanel.swift`

**Step 1: Create the NSPanel subclass**

Create `Orbit/RadialMenu/RadialMenuPanel.swift`:

```swift
import AppKit
import SwiftUI

final class RadialMenuPanel: NSPanel {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 320),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        worksWhenModal = true

        collectionBehavior = [
            .fullScreenAuxiliary,
            .canJoinAllSpaces,
            .stationary
        ]

        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func setContent<Content: View>(@ViewBuilder _ content: () -> Content) {
        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 160  // half of 320
        effectView.layer?.masksToBounds = true
        effectView.translatesAutoresizingMaskIntoConstraints = false

        let hostingView = NSHostingView(rootView: content().ignoresSafeArea())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(hostingView)

        self.contentView = effectView

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: effectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
        ])
    }

    func showAtMouseLocation() {
        let mouse = NSEvent.mouseLocation
        let size = frame.size
        let origin = CGPoint(
            x: mouse.x - size.width / 2,
            y: mouse.y - size.height / 2
        )

        // Clamp to screen bounds
        if let screen = NSScreen.screens.first(where: {
            $0.frame.contains(NSPoint(x: mouse.x, y: mouse.y))
        }) ?? NSScreen.main {
            let vis = screen.visibleFrame
            let clamped = CGPoint(
                x: min(max(origin.x, vis.minX), vis.maxX - size.width),
                y: min(max(origin.y, vis.minY), vis.maxY - size.height)
            )
            setFrameOrigin(clamped)
        } else {
            setFrameOrigin(origin)
        }

        orderFront(nil)
    }

    func dismiss() {
        orderOut(nil)
    }
}
```

**Step 2: Verify it builds**

Run: `swift build`
Expected: Successful build.

**Step 3: Commit**

```bash
git add Orbit/RadialMenu/RadialMenuPanel.swift
git commit -m "feat: add RadialMenuPanel NSPanel subclass with glassmorphism"
```

---

### Task 6: Radial Menu ViewModel

**Files:**
- Create: `Orbit/RadialMenu/RadialMenuViewModel.swift`

**Step 1: Create the ViewModel**

Create `Orbit/RadialMenu/RadialMenuViewModel.swift`:

```swift
import Foundation
import AppKit

@Observable
final class RadialMenuViewModel {
    var sectors: [SectorItem] = []
    var selectedIndex: Int? = nil
    var isVisible: Bool = false

    /// Center of the panel in screen coordinates
    var centerPoint: CGPoint = .zero

    private let deadZoneRadius: CGFloat = 30

    struct SectorItem: Identifiable {
        let id: String
        let name: String
        let icon: NSImage?
        let action: (any OrbitAction)?
    }

    /// Calculate which sector the mouse is pointing at.
    /// `mouseLocation` is in screen coordinates.
    func updateSelection(mouseLocation: CGPoint) {
        let dx = mouseLocation.x - centerPoint.x
        let dy = mouseLocation.y - centerPoint.y
        let distance = sqrt(dx * dx + dy * dy)

        guard distance > deadZoneRadius else {
            selectedIndex = nil
            return
        }

        guard !sectors.isEmpty else {
            selectedIndex = nil
            return
        }

        // atan2 returns radians from -pi to pi, with 0 pointing right
        var angle = atan2(dy, dx)

        // Convert to 0...2pi, with 0 pointing up (top), clockwise
        // Subtract pi/2 to rotate so 0 = top
        angle = -(angle - .pi / 2)

        // Normalize to 0...2pi
        if angle < 0 { angle += 2 * .pi }

        let sectorAngle = (2 * .pi) / CGFloat(sectors.count)
        let index = Int(angle / sectorAngle) % sectors.count

        selectedIndex = index
    }

    /// Build sectors from config + recent apps.
    func buildSectors(config: OrbitConfig, recentApps: [RecentAppsTracker.AppInfo]) {
        var recentIndex = 0
        var items: [SectorItem] = []

        for sectorConfig in config.sectors.prefix(config.sectorCount) {
            switch sectorConfig {
            case .recent:
                if recentIndex < recentApps.count {
                    let app = recentApps[recentIndex]
                    let action = LaunchAppAction(
                        id: app.id,
                        name: app.name,
                        bundleIdentifier: app.id
                    )
                    items.append(SectorItem(
                        id: "recent-\(recentIndex)",
                        name: app.name,
                        icon: app.icon,
                        action: action
                    ))
                } else {
                    items.append(SectorItem(
                        id: "empty-\(recentIndex)",
                        name: "Empty",
                        icon: NSImage(systemSymbolName: "circle.dashed", accessibilityDescription: nil),
                        action: nil
                    ))
                }
                recentIndex += 1

            case .pinned(let bundleId, let name, _):
                let action = LaunchAppAction(
                    id: bundleId,
                    name: name,
                    bundleIdentifier: bundleId
                )
                items.append(SectorItem(
                    id: "pinned-\(bundleId)",
                    name: name,
                    icon: action.icon.nsImage,
                    action: action
                ))
            }
        }

        sectors = items
    }

    /// Execute the currently selected sector's action.
    func executeSelected() async {
        guard let index = selectedIndex, index < sectors.count,
              let action = sectors[index].action else { return }
        await action.execute()
    }
}
```

**Step 2: Verify it builds**

Run: `swift build`
Expected: Successful build.

**Step 3: Commit**

```bash
git add Orbit/RadialMenu/RadialMenuViewModel.swift
git commit -m "feat: add RadialMenuViewModel with angle calculation and sector building"
```

---

### Task 7: Radial Menu SwiftUI Views

**Files:**
- Create: `Orbit/RadialMenu/RadialMenuView.swift`
- Create: `Orbit/RadialMenu/SectorView.swift`

**Step 1: Create the sector view**

Create `Orbit/RadialMenu/SectorView.swift`:

```swift
import SwiftUI

struct SectorView: View {
    let item: RadialMenuViewModel.SectorItem
    let isSelected: Bool
    let angle: Angle
    let radius: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "questionmark.app")
                    .font(.system(size: 28))
                    .frame(width: 40, height: 40)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(
                    color: .black.opacity(isSelected ? 0.4 : 0.2),
                    radius: isSelected ? 8 : 4,
                    y: isSelected ? 4 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    .white.opacity(isSelected ? 0.8 : 0.1),
                    lineWidth: isSelected ? 2 : 0.5
                )
        )
        .scaleEffect(isSelected ? 1.15 : 0.9)
        .opacity(isSelected ? 1.0 : 0.6)
        .brightness(isSelected ? 0.1 : 0)
        .offset(
            x: cos(angle.radians) * radius,
            y: -sin(angle.radians) * radius  // negative because SwiftUI y is flipped
        )
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
    }
}
```

**Step 2: Create the radial menu view**

Create `Orbit/RadialMenu/RadialMenuView.swift`:

```swift
import SwiftUI

struct RadialMenuView: View {
    let viewModel: RadialMenuViewModel

    private let diameter: CGFloat = 320
    private let iconRingRadius: CGFloat = 110
    private let centerRadius: CGFloat = 40

    var body: some View {
        ZStack {
            // Center label
            VStack(spacing: 2) {
                if let index = viewModel.selectedIndex, index < viewModel.sectors.count {
                    Text(viewModel.sectors[index].name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .transition(.opacity)
                        .id(viewModel.sectors[index].id)
                } else {
                    Text("Orbit")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: centerRadius * 2, height: centerRadius * 2)
            .animation(.easeInOut(duration: 0.15), value: viewModel.selectedIndex)

            // Sector icons in a ring
            ForEach(Array(viewModel.sectors.enumerated()), id: \.element.id) { index, item in
                let sectorAngle = sectorAngle(for: index)
                SectorView(
                    item: item,
                    isSelected: viewModel.selectedIndex == index,
                    angle: sectorAngle,
                    radius: iconRingRadius
                )
            }
        }
        .frame(width: diameter, height: diameter)
    }

    /// Calculate the angle for a sector, starting from top (12 o'clock), going clockwise.
    private func sectorAngle(for index: Int) -> Angle {
        let count = viewModel.sectors.count
        guard count > 0 else { return .zero }
        // Start at 90 degrees (top), go clockwise
        let step = 360.0 / Double(count)
        return .degrees(90 - step * Double(index))
    }
}
```

**Step 3: Verify it builds**

Run: `swift build`
Expected: Successful build.

**Step 4: Commit**

```bash
git add Orbit/RadialMenu/RadialMenuView.swift Orbit/RadialMenu/SectorView.swift
git commit -m "feat: add radial menu SwiftUI views with selection animation"
```

---

### Task 8: Global Hotkey Manager

**Files:**
- Create: `Orbit/HotkeyManager/KeyCombo.swift`
- Create: `Orbit/HotkeyManager/HotkeyManager.swift`

**Step 1: Create the key combo model**

Create `Orbit/HotkeyManager/KeyCombo.swift`:

```swift
import Carbon.HIToolbox
import CoreGraphics

struct KeyCombo: Equatable {
    let keyCode: Int64
    let modifiers: CGEventFlags

    /// Common key codes
    static let keyCodes: [String: Int64] = [
        "space": Int64(kVK_Space),
        "return": Int64(kVK_Return),
        "tab": Int64(kVK_Tab),
        "escape": Int64(kVK_Escape),
        "a": Int64(kVK_ANSI_A), "b": Int64(kVK_ANSI_B), "c": Int64(kVK_ANSI_C),
        "d": Int64(kVK_ANSI_D), "e": Int64(kVK_ANSI_E), "f": Int64(kVK_ANSI_F),
        "g": Int64(kVK_ANSI_G), "h": Int64(kVK_ANSI_H), "i": Int64(kVK_ANSI_I),
        "j": Int64(kVK_ANSI_J), "k": Int64(kVK_ANSI_K), "l": Int64(kVK_ANSI_L),
        "m": Int64(kVK_ANSI_M), "n": Int64(kVK_ANSI_N), "o": Int64(kVK_ANSI_O),
        "p": Int64(kVK_ANSI_P), "q": Int64(kVK_ANSI_Q), "r": Int64(kVK_ANSI_R),
        "s": Int64(kVK_ANSI_S), "t": Int64(kVK_ANSI_T), "u": Int64(kVK_ANSI_U),
        "v": Int64(kVK_ANSI_V), "w": Int64(kVK_ANSI_W), "x": Int64(kVK_ANSI_X),
        "y": Int64(kVK_ANSI_Y), "z": Int64(kVK_ANSI_Z),
    ]

    static let modifierMap: [String: CGEventFlags] = [
        "command": .maskCommand,
        "shift": .maskShift,
        "option": .maskAlternate,
        "control": .maskControl,
    ]

    init(key: String, modifiers: [String]) {
        self.keyCode = KeyCombo.keyCodes[key.lowercased()] ?? Int64(kVK_Space)
        self.modifiers = modifiers.reduce(CGEventFlags()) { result, mod in
            result.union(KeyCombo.modifierMap[mod.lowercased()] ?? [])
        }
    }

    init(from config: OrbitConfig.HotkeyConfig) {
        self.init(key: config.key, modifiers: config.modifiers)
    }

    func matches(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard keyCode == self.keyCode else { return false }
        // Check that all required modifiers are present
        return flags.contains(modifiers)
    }

    func modifiersMatch(flags: CGEventFlags) -> Bool {
        return flags.contains(modifiers)
    }
}
```

**Step 2: Create the hotkey manager**

Create `Orbit/HotkeyManager/HotkeyManager.swift`:

```swift
import CoreGraphics
import AppKit

/// Callback must be a free function for CGEvent tap C bridge.
private func hotkeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Re-enable tap if it was disabled
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let userInfo {
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            if let port = manager.eventTapPort {
                CGEvent.tapEnable(tap: port, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    switch type {
    case .keyDown:
        manager.handleKeyDown(keyCode: keyCode, flags: flags)
    case .keyUp:
        manager.handleKeyUp(keyCode: keyCode, flags: flags)
    case .flagsChanged:
        manager.handleFlagsChanged(keyCode: keyCode, flags: flags)
    default:
        break
    }

    return Unmanaged.passUnretained(event)
}

@Observable
final class HotkeyManager {
    fileprivate var eventTapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthCheckTimer: Timer?

    var keyCombo: KeyCombo = KeyCombo(key: "space", modifiers: ["control"])
    private(set) var isHotkeyHeld = false

    var onHotkeyDown: (() -> Void)?
    var onHotkeyUp: (() -> Void)?

    // MARK: - Permission

    static func hasPermission() -> Bool {
        CGPreflightListenEventAccess()
    }

    static func requestPermission() {
        CGRequestListenEventAccess()
    }

    // MARK: - Start / Stop

    @discardableResult
    func start() -> Bool {
        guard HotkeyManager.hasPermission() else {
            HotkeyManager.requestPermission()
            return false
        }

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: hotkeyEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create CGEvent tap")
            return false
        }

        eventTapPort = port

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            print("Failed to create run loop source")
            return false
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)

        // Health check: re-enable tap if silently disabled
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self, let port = self.eventTapPort else { return }
            if !CGEvent.tapIsEnabled(tap: port) {
                CGEvent.tapEnable(tap: port, enable: true)
            }
        }

        return true
    }

    func stop() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil

        if let port = eventTapPort {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        eventTapPort = nil
        runLoopSource = nil
    }

    // MARK: - Event Handlers

    fileprivate func handleKeyDown(keyCode: Int64, flags: CGEventFlags) {
        if !isHotkeyHeld && keyCombo.matches(keyCode: keyCode, flags: flags) {
            isHotkeyHeld = true
            DispatchQueue.main.async { [self] in
                onHotkeyDown?()
            }
        }

        // Esc cancels while menu is shown
        if isHotkeyHeld && keyCode == 53 /* kVK_Escape */ {
            isHotkeyHeld = false
            DispatchQueue.main.async { [self] in
                onHotkeyUp?()
            }
        }
    }

    fileprivate func handleKeyUp(keyCode: Int64, flags: CGEventFlags) {
        if isHotkeyHeld && keyCode == keyCombo.keyCode {
            isHotkeyHeld = false
            DispatchQueue.main.async { [self] in
                onHotkeyUp?()
            }
        }
    }

    fileprivate func handleFlagsChanged(keyCode: Int64, flags: CGEventFlags) {
        // If modifiers were released while hotkey is held, treat as release
        if isHotkeyHeld && !keyCombo.modifiersMatch(flags: flags) {
            isHotkeyHeld = false
            DispatchQueue.main.async { [self] in
                onHotkeyUp?()
            }
        }
    }
}
```

**Step 3: Verify it builds**

Run: `swift build`
Expected: Successful build.

**Step 4: Commit**

```bash
git add Orbit/HotkeyManager/
git commit -m "feat: add global hotkey manager using CGEvent tap"
```

---

### Task 9: Orbit Controller (Wire Everything Together)

**Files:**
- Create: `Orbit/OrbitController.swift`
- Modify: `Orbit/OrbitApp.swift`
- Modify: `Orbit/AppDelegate.swift`

**Step 1: Create the main controller**

Create `Orbit/OrbitController.swift`:

```swift
import AppKit
import SwiftUI

@Observable
final class OrbitController {
    let configManager: ConfigManager
    let recentAppsTracker: RecentAppsTracker
    let hotkeyManager: HotkeyManager
    let viewModel: RadialMenuViewModel

    private var panel: RadialMenuPanel?
    private var mouseMonitor: Any?

    init() {
        configManager = ConfigManager()
        recentAppsTracker = RecentAppsTracker()
        hotkeyManager = HotkeyManager()
        viewModel = RadialMenuViewModel()

        setupHotkey()
    }

    private func setupHotkey() {
        let config = configManager.config
        hotkeyManager.keyCombo = KeyCombo(from: config.hotkey)

        hotkeyManager.onHotkeyDown = { [weak self] in
            self?.showMenu()
        }

        hotkeyManager.onHotkeyUp = { [weak self] in
            self?.hideMenuAndExecute()
        }
    }

    func startListening() {
        if !hotkeyManager.start() {
            print("Hotkey manager failed to start. Check Input Monitoring permission.")
        }
    }

    private func showMenu() {
        viewModel.buildSectors(
            config: configManager.config,
            recentApps: recentAppsTracker.topRecent(configManager.config.sectorCount)
        )
        viewModel.selectedIndex = nil
        viewModel.isVisible = true
        viewModel.centerPoint = NSEvent.mouseLocation

        let panel = RadialMenuPanel()
        panel.setContent {
            RadialMenuView(viewModel: self.viewModel)
        }
        panel.showAtMouseLocation()
        self.panel = panel

        // Start mouse tracking
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.viewModel.updateSelection(mouseLocation: NSEvent.mouseLocation)
        }

        // Also track local events (within our panel)
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.viewModel.updateSelection(mouseLocation: NSEvent.mouseLocation)
            return event
        }

        // Store both monitors - we'll use a simple approach: keep local monitor reference
        // by replacing mouseMonitor with a combined cleanup
        let globalMonitor = mouseMonitor
        mouseMonitor = (globalMonitor, localMonitor) as AnyObject
    }

    private func hideMenuAndExecute() {
        // Execute selected action
        let shouldExecute = viewModel.selectedIndex != nil
        if shouldExecute {
            Task {
                await viewModel.executeSelected()
            }
        }

        // Clean up mouse monitors
        if let monitors = mouseMonitor as? (Any?, Any?) {
            if let global = monitors.0 { NSEvent.removeMonitor(global) }
            if let local = monitors.1 { NSEvent.removeMonitor(local) }
        } else if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        mouseMonitor = nil

        // Hide panel
        viewModel.isVisible = false
        viewModel.selectedIndex = nil
        panel?.dismiss()
        panel = nil
    }
}
```

**Step 2: Update OrbitApp.swift to wire in the controller**

Replace `Orbit/OrbitApp.swift`:

```swift
import SwiftUI

@main
struct OrbitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 8) {
                Text("Orbit")
                    .font(.headline)

                if !HotkeyManager.hasPermission() {
                    Button("Grant Input Monitoring Permission") {
                        HotkeyManager.requestPermission()
                    }
                } else {
                    Text("Ready (Ctrl+Space)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(4)
        } label: {
            Label("Orbit", systemImage: "circle.grid.2x2")
        }
        .menuBarExtraStyle(.menu)
    }
}
```

**Step 3: Update AppDelegate.swift to start the controller**

Replace `Orbit/AppDelegate.swift`:

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: OrbitController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        controller = OrbitController()
        controller?.startListening()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
```

**Step 4: Verify it builds**

Run: `swift build`
Expected: Successful build.

**Step 5: Run and test manually**

Run: `swift run`
Expected:
- Menu bar icon appears
- If Input Monitoring not granted, permission prompt appears
- After granting permission, Ctrl+Space shows radial menu at mouse position
- Moving mouse highlights different sectors
- Releasing keys executes selected app or closes without action

**Step 6: Commit**

```bash
git add Orbit/OrbitController.swift Orbit/OrbitApp.swift Orbit/AppDelegate.swift
git commit -m "feat: wire up OrbitController connecting hotkey, panel, and actions"
```

---

### Task 10: Polish Animations & Visual Refinement

**Files:**
- Modify: `Orbit/RadialMenu/RadialMenuView.swift`
- Modify: `Orbit/RadialMenu/RadialMenuPanel.swift`
- Modify: `Orbit/OrbitController.swift`

**Step 1: Add appear/disappear animations to the radial menu view**

Update `Orbit/RadialMenu/RadialMenuView.swift` - wrap the view body in an animation container:

```swift
import SwiftUI

struct RadialMenuView: View {
    let viewModel: RadialMenuViewModel
    @State private var isAppearing = false

    private let diameter: CGFloat = 320
    private let iconRingRadius: CGFloat = 110
    private let centerRadius: CGFloat = 40

    var body: some View {
        ZStack {
            // Center label
            VStack(spacing: 2) {
                if let index = viewModel.selectedIndex, index < viewModel.sectors.count {
                    Text(viewModel.sectors[index].name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .transition(.opacity)
                        .id(viewModel.sectors[index].id)
                } else {
                    Text("Orbit")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: centerRadius * 2, height: centerRadius * 2)
            .animation(.easeInOut(duration: 0.15), value: viewModel.selectedIndex)

            // Sector icons in a ring
            ForEach(Array(viewModel.sectors.enumerated()), id: \.element.id) { index, item in
                let sectorAngle = sectorAngle(for: index)
                SectorView(
                    item: item,
                    isSelected: viewModel.selectedIndex == index,
                    angle: sectorAngle,
                    radius: iconRingRadius
                )
                .opacity(isAppearing ? 1 : 0)
                .scaleEffect(isAppearing ? 1 : 0.3)
                .animation(
                    .spring(duration: 0.3, bounce: 0.25)
                        .delay(Double(index) * 0.02),
                    value: isAppearing
                )
            }
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(isAppearing ? 1 : 0.8)
        .opacity(isAppearing ? 1 : 0)
        .animation(.spring(duration: 0.25, bounce: 0.2), value: isAppearing)
        .onAppear {
            isAppearing = true
        }
    }

    private func sectorAngle(for index: Int) -> Angle {
        let count = viewModel.sectors.count
        guard count > 0 else { return .zero }
        let step = 360.0 / Double(count)
        return .degrees(90 - step * Double(index))
    }
}
```

**Step 2: Add dismiss animation to the panel**

Update `RadialMenuPanel.dismiss()` in `Orbit/RadialMenu/RadialMenuPanel.swift`:

```swift
    func dismiss() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.alphaValue = 1  // Reset for next show
        })
    }

    func showAtMouseLocation() {
        alphaValue = 1  // Ensure full opacity on show
        let mouse = NSEvent.mouseLocation
        let size = frame.size
        let origin = CGPoint(
            x: mouse.x - size.width / 2,
            y: mouse.y - size.height / 2
        )

        if let screen = NSScreen.screens.first(where: {
            $0.frame.contains(NSPoint(x: mouse.x, y: mouse.y))
        }) ?? NSScreen.main {
            let vis = screen.visibleFrame
            let clamped = CGPoint(
                x: min(max(origin.x, vis.minX), vis.maxX - size.width),
                y: min(max(origin.y, vis.minY), vis.maxY - size.height)
            )
            setFrameOrigin(clamped)
        } else {
            setFrameOrigin(origin)
        }

        orderFront(nil)
    }
```

**Step 3: Verify it builds and test**

Run: `swift build && swift run`
Expected: Smooth spring animations on appear, staggered icon entrance, fast fade on dismiss.

**Step 4: Commit**

```bash
git add Orbit/RadialMenu/RadialMenuView.swift Orbit/RadialMenu/RadialMenuPanel.swift Orbit/OrbitController.swift
git commit -m "feat: add spring animations for appear/disappear and selection transitions"
```

---

### Task 11: Permission Onboarding Flow

**Files:**
- Create: `Orbit/Onboarding/PermissionView.swift`
- Modify: `Orbit/AppDelegate.swift`

**Step 1: Create the permission guidance view**

Create `Orbit/Onboarding/PermissionView.swift`:

```swift
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
                    // Also open the settings pane directly
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
```

**Step 2: Update AppDelegate to show onboarding if needed**

Update `Orbit/AppDelegate.swift`:

```swift
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: OrbitController?
    var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if HotkeyManager.hasPermission() {
            startOrbit()
        } else {
            showOnboarding()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func startOrbit() {
        onboardingWindow?.close()
        onboardingWindow = nil
        NSApp.setActivationPolicy(.accessory)

        controller = OrbitController()
        controller?.startListening()
    }

    private func showOnboarding() {
        NSApp.setActivationPolicy(.regular)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Orbit"
        window.center()
        window.contentView = NSHostingView(rootView: PermissionView {
            DispatchQueue.main.async { [weak self] in
                self?.startOrbit()
            }
        })
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }
}
```

**Step 3: Verify it builds**

Run: `swift build`
Expected: Successful build.

**Step 4: Commit**

```bash
git add Orbit/Onboarding/ Orbit/AppDelegate.swift
git commit -m "feat: add permission onboarding flow for Input Monitoring"
```

---

### Task 12: End-to-End Integration Test

This is a manual verification task (GUI apps are hard to unit test for interaction). We verify the full flow.

**Step 1: Build the app**

Run: `swift build`
Expected: Clean build, no warnings.

**Step 2: Run the app**

Run: `swift run`
Expected:
1. If first run: Onboarding window appears asking for Input Monitoring permission.
2. After granting: Window closes, menu bar icon appears.
3. Press and hold Ctrl+Space: Radial menu appears at mouse position with glassmorphism background.
4. Move mouse: Sectors highlight based on direction. Center label shows selected app name.
5. Release Ctrl+Space: Selected app launches/activates. Menu disappears.
6. Hold Ctrl+Space then press Esc: Menu disappears without executing.
7. Hold Ctrl+Space and release in center dead zone: Menu disappears without executing.

**Step 3: Verify menu bar**

Click menu bar icon → Shows "Ready (Ctrl+Space)" text and Quit button.

**Step 4: Verify config file**

Run: `cat ~/Library/Application\ Support/Orbit/config.json`
Expected: JSON with default config (8 recent sectors, Ctrl+Space hotkey).

**Step 5: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: address integration test issues"
```

---

## Summary

| Task | Component | Key Files |
|------|-----------|-----------|
| 1 | Project Skeleton | `Package.swift`, `OrbitApp.swift`, `AppDelegate.swift` |
| 2 | Config System | `OrbitConfig.swift`, `ConfigManager.swift` |
| 3 | Recent Apps | `RecentAppsTracker.swift` |
| 4 | Actions | `OrbitAction.swift`, `LaunchAppAction.swift` |
| 5 | Panel | `RadialMenuPanel.swift` |
| 6 | ViewModel | `RadialMenuViewModel.swift` |
| 7 | Views | `RadialMenuView.swift`, `SectorView.swift` |
| 8 | Hotkey | `KeyCombo.swift`, `HotkeyManager.swift` |
| 9 | Controller | `OrbitController.swift`, app wiring |
| 10 | Animations | View polish, appear/disappear |
| 11 | Onboarding | `PermissionView.swift`, permission flow |
| 12 | Integration | End-to-end manual verification |
