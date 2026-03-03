# Orbit Design Document

## Overview

Orbit is a macOS native "hold-to-invoke" radial shortcut menu (weapon wheel style, like GTA/RDR2) for quickly launching apps and triggering actions. The user holds a hotkey, points toward a sector, and releases to execute. The whole interaction is click-free.

## Decisions

| Decision | Choice |
|----------|--------|
| Tech stack | SwiftUI + AppKit |
| macOS target | 15 Sequoia+ |
| Default hotkey | Configurable combo key (e.g. Ctrl+Space) |
| Config storage | JSON file at `~/Library/Application Support/Orbit/config.json` |
| Distribution | Direct (no sandbox, GitHub Releases / .dmg) |
| Architecture | NSPanel floating overlay + SwiftUI content |
| Default sectors | Dynamic recent apps + pinnable positions |

## Architecture

### Application Type

Menu bar app (no Dock icon). Lives in the menu bar tray.

### Module Structure

```
Orbit/
├── App/
│   ├── OrbitApp.swift              # @main entry, menu bar config
│   └── AppDelegate.swift           # NSApplicationDelegate, permission guidance
├── HotkeyManager/
│   ├── HotkeyManager.swift         # Global hotkey listener (CGEvent tap)
│   └── KeyCombo.swift              # Key combination model
├── RadialMenu/
│   ├── RadialMenuPanel.swift       # NSPanel subclass, overlay window management
│   ├── RadialMenuView.swift        # SwiftUI radial menu main view
│   ├── SectorView.swift            # Individual sector view
│   └── RadialMenuViewModel.swift   # Selection state, angle calculation
├── Actions/
│   ├── ActionProtocol.swift        # Action protocol definition
│   ├── LaunchAppAction.swift       # Launch/switch to app
│   └── CustomAction.swift          # Custom placeholder action
├── Config/
│   ├── ConfigManager.swift         # JSON config read/write
│   └── OrbitConfig.swift           # Config model (Codable)
├── RecentApps/
│   └── RecentAppsTracker.swift     # Tracks recently used apps via workspace notifications
└── Settings/
    └── SettingsView.swift          # Settings UI (SwiftUI)
```

### Key Architectural Decisions

- `HotkeyManager` uses `CGEvent.tapCreate()` to listen for key down/up events. Requires Accessibility permission.
- `RadialMenuPanel` is an `NSPanel` subclass with `.nonactivatingPanel` level and `canBecomeKey = false`, ensuring it never steals focus from the current app.
- Mouse tracking uses `NSEvent.addLocalMonitorForEvents` within the panel.
- SwiftUI views are driven by an `@Observable` ViewModel that computes mouse direction angle to selected sector index.

## Global Hotkey & Menu Lifecycle

### Hotkey Listening

- `CGEvent.tapCreate()` monitors `keyDown`, `keyUp`, and `flagsChanged` events.
- Requires Accessibility permission (`AXIsProcessTrusted()`).

### Flow

1. **Key down**: Record mouse position via `NSEvent.mouseLocation` → Center panel on mouse → `orderFront` → Start mouse tracking.
2. **Mouse move**: Compute angle from center using `atan2(dy, dx)` → Map to sector index → Update ViewModel.
3. **Key up**: If sector selected → Execute action → Hide panel. If in dead zone → Cancel.
4. **Esc pressed**: Cancel → Hide panel, execute nothing.

### Mouse Direction Calculation

- Center point = Panel center (trigger mouse position).
- Angle: `atan2(dy, dx)`, offset by -90 degrees so sector 0 starts at top.
- Dead zone: Mouse distance < 30pt from center → No sector selected.
- N sectors → Each sector spans 360/N degrees, arranged clockwise from top.

## Radial Menu UI & Visuals

### Layout

- Panel size: ~320x320pt.
- Center circle: ~40pt radius, displays selected item name.
- Sector icon ring: ~120pt radius, icons evenly distributed.
- Each sector icon: 48x48pt rounded rectangle with app icon or SF Symbol.

### Visual Stack

1. **Bottom**: `NSVisualEffectView` with `.hudWindow` material, `.behindWindow` blending mode, clipped to circle.
2. **Middle**: SwiftUI sector icon ring — each icon has a rounded rect background + shadow.
3. **Top**: Center label — selected item name + optional subtitle.

### Selection Animation

- **Selected**: `scaleEffect(1.15)` + white/highlight border + enhanced shadow + brightness boost.
- **Unselected**: `scaleEffect(0.9)` + `opacity(0.6)`.
- **Transition**: `.spring(duration: 0.3, bounce: 0.2)`.
- **Center label**: Crossfade on selection change.

### Appear/Disappear Animation

- **Appear**: `scale(0.8) + opacity(0)` → `scale(1.0) + opacity(1.0)`, spring ~0.25s. Icons stagger by 0.02s each.
- **Disappear**: `scale(0.95) + opacity(0)`, fast fade ~0.15s.

### Glassmorphism

- `NSVisualEffectView` with `.hudWindow` material, bridged to SwiftUI via `NSViewRepresentable`.
- Circular shape with subtle edge shadow.

## Action System

### Protocol

```swift
protocol OrbitAction {
    var id: String { get }
    var name: String { get }
    var icon: ActionIcon { get }  // .appIcon(bundleID) or .sfSymbol(name)
    var subtitle: String? { get }
    func execute() async throws
}

enum ActionIcon: Codable {
    case appIcon(bundleId: String)
    case sfSymbol(name: String)
}
```

### MVP Action Types

1. **LaunchAppAction**: Opens or switches to an app via `NSWorkspace.shared.open(_:configuration:)` using bundle identifier.
2. **CustomAction**: Placeholder for future extensibility. Logs or shows notification in MVP.

### App Icon Retrieval

`NSWorkspace.shared.icon(forFile:)` with the app's bundle path from `NSRunningApplication.bundleURL`.

## Configuration

### Model

```json
{
  "hotkey": { "key": "space", "modifiers": ["control"] },
  "sectorCount": 8,
  "sectors": [
    { "type": "recent", "index": 0 },
    { "type": "recent", "index": 1 },
    { "type": "pinned", "bundleId": "com.apple.Terminal", "name": "Terminal" },
    { "type": "recent", "index": 2 },
    { "type": "recent", "index": 3 },
    { "type": "recent", "index": 4 },
    { "type": "recent", "index": 5 },
    { "type": "recent", "index": 6 }
  ]
}
```

### Default Behavior

- All sectors default to `recent` (dynamic, filled with recently used apps).
- Users can pin any position to a fixed app/action.
- Recent apps tracked via `NSWorkspace.didActivateApplicationNotification`.
- Orbit itself and Finder excluded from recent list.

### File Path

`~/Library/Application Support/Orbit/config.json`

## Permissions & Onboarding

### Required Permission

Accessibility permission only (`AXIsProcessTrusted()`), needed for `CGEvent` tap global hotkey listening.

### First Launch Flow

1. Check `AXIsProcessTrusted()`.
2. If `false`: Show guidance window explaining why Accessibility permission is needed.
3. Button opens System Settings → Privacy & Security → Accessibility directly.
4. Background polling detects permission grant → Auto-transition to ready state.

## Settings UI

Menu bar click opens settings window (SwiftUI):

- **Hotkey**: Record a new key combination.
- **Sectors**: List view with drag-to-reorder, toggle recent/pinned, pick pinned app.
- **General**: Launch at login (`SMAppService`), sector count (4/6/8/12).

MVP simplification: Hotkey config + sector list editing only.

## MVP Acceptance Criteria

1. Hold trigger key → Orbit radial menu appears at mouse position.
2. Mouse direction selects sectors with real-time highlight feedback.
3. Release trigger key → Executes selected action (at minimum: open/switch to app).
4. Cancel (Esc or release in dead zone) → Closes without executing.
5. macOS native glassmorphism + floating icon aesthetic.
6. Default sectors auto-populate with recently used apps.
