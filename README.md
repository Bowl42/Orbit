<h1 align="center">Orbit</h1>

<p align="center">
  <strong>Hold. Point. Launch.</strong><br>
  A radial app launcher for macOS, triggered by hotkey.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-15%2B-blue?style=flat-square&logo=apple" alt="macOS 15+" />
  <img src="https://img.shields.io/badge/Swift-6-orange?style=flat-square&logo=swift" alt="Swift 6" />
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="MIT License" />
</p>

---

## What is Orbit?

Orbit is a **weapon-wheel style** radial menu that lives in your menu bar. Hold your hotkey, point toward an app, release — done. No clicking, no searching, no Dock diving.

- **Hold** a mouse button or keyboard shortcut
- **Point** toward the sector of the app you want
- **Release** to instantly switch to it

The menu appears at your cursor, shows your recent apps (or pinned favorites), and disappears the moment you let go.

---

## Features

- **Radial Menu** — Glassmorphic floating overlay with smooth spring animations. 8 configurable sectors, each holding a recent or pinned app.
- **Flexible Hotkey** — Trigger with mouse side buttons (Mouse4/Mouse5) or any keyboard shortcut with modifier keys (`⌃` `⌥` `⇧` `⌘`).
- **Sector Pinning** — Pin your most-used apps to fixed positions. Unassigned sectors auto-fill with your recent apps.
- **Menu Bar Native** — Lives quietly in your menu bar. No Dock icon, no window clutter. Open settings or quit from the menu bar popover.

---

## Getting Started

### Requirements

- macOS 15 (Sequoia) or later
- Swift 6 toolchain

### Build & Install

```bash
# Clone
git clone https://github.com/Bowl42/Orbit.git
cd Orbit

# Build and install to /Applications
bash scripts/bundle.sh
```

This creates **`/Applications/Orbit.app`**, code-signed to preserve system permissions.

### Permissions

On first launch, Orbit will ask for two system permissions:

| Permission | Why |
|---|---|
| **Accessibility** | Intercept global hotkey events |
| **Input Monitoring** | Detect keyboard and mouse button presses |

Grant both in **System Settings > Privacy & Security**. Orbit checks status automatically — no restart needed.

---

## Usage

1. **Launch** Orbit — it appears in the menu bar
2. **Hold** your hotkey (default: **Mouse 4 / Side Button**)
3. **Move** mouse toward the app you want — the sector highlights
4. **Release** to switch to that app
5. Release in the **center dead zone** or press **Esc** to cancel

### Default Config

| Setting | Default |
|---|---|
| Trigger | Mouse 4 (Side Button) |
| Sectors | 8 (all recent apps) |
| Modifiers | None |

---

## Configuration

Open settings from the menu bar popover or on first launch.

### General Tab

- **Trigger type**: Keyboard hotkey or mouse button
- **Key / Button**: Space, Return, A–Z, Mouse 3/4/5
- **Modifiers**: Any combination of `⌃` `⌥` `⇧` `⌘`
- **Live preview**: See your hotkey combo as you configure it

### Sectors Tab

- **Ring preview**: Click any sector dot to select it
- **Recent**: Auto-fills with your most recently used apps
- **Pinned**: Lock a specific app to that sector position
- **App picker**: Search and select from all installed apps

Config is stored at `~/Library/Application Support/Orbit/config.json`.

---

## Architecture

```
Orbit/
├── OrbitApp.swift              # @main, MenuBarExtra
├── AppDelegate.swift           # Lifecycle, permissions
├── OrbitController.swift       # Core orchestrator
├── HotkeyManager/
│   ├── HotkeyManager.swift     # CGEvent tap listener
│   └── KeyCombo.swift          # Key combo model
├── RadialMenu/
│   ├── RadialMenuView.swift    # SwiftUI radial UI
│   ├── RadialMenuPanel.swift   # NSPanel overlay
│   ├── SectorView.swift        # Sector wedge component
│   └── RadialMenuViewModel.swift
├── Actions/
│   ├── OrbitAction.swift       # Action protocol
│   └── LaunchAppAction.swift   # App launch action
├── Config/
│   ├── ConfigManager.swift     # JSON I/O
│   └── OrbitConfig.swift       # Config model
├── RecentApps/
│   └── RecentAppsTracker.swift # Recent app tracking
└── Settings/
    ├── SettingsView.swift      # Settings UI
    ├── AppPickerView.swift     # App picker modal
    └── InstalledAppsFinder.swift
```

**Key design decisions:**
- **NSPanel** (non-activating) — menu never steals focus from your active app
- **CGEvent tap** — low-level, reliable global hotkey detection
- **SwiftUI + AppKit bridge** — modern UI with native macOS window management
- **@Observable** — reactive state without Combine boilerplate

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI with `.ultraThinMaterial` glassmorphism |
| Window | NSPanel (non-activating, transparent) |
| Hotkey | CGEvent tap via CoreGraphics |
| App launch | NSWorkspace |
| Config | Codable JSON |
| Build | Swift Package Manager |
| Signing | Apple Development identity |

---

## License

MIT

---

<p align="center">
  <sub>Built with SwiftUI on macOS Sequoia.</sub>
</p>
