import AppKit
import SwiftUI

@MainActor
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

    func applyHotkey() {
        hotkeyManager.keyCombo = KeyCombo(from: configManager.config.hotkey)
    }

    private func setupHotkey() {
        applyHotkey()

        hotkeyManager.onHotkeyDown = { [weak self] in
            MainActor.assumeIsolated {
                self?.showMenu()
            }
        }

        hotkeyManager.onHotkeyUp = { [weak self] in
            MainActor.assumeIsolated {
                self?.hideMenuAndExecute()
            }
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

        let panel = RadialMenuPanel()
        panel.setContent {
            RadialMenuView(viewModel: self.viewModel)
        }
        // Use the actual panel center (accounts for screen-edge clamping)
        viewModel.centerPoint = panel.showAtMouseLocation()
        self.panel = panel

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.viewModel.updateSelection(mouseLocation: NSEvent.mouseLocation)
            }
        }
    }

    private func hideMenuAndExecute() {
        let selectedIndex = viewModel.selectedIndex
        let sectors = viewModel.sectors

        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        mouseMonitor = nil

        viewModel.isVisible = false
        viewModel.selectedIndex = nil
        panel?.dismiss()
        panel = nil

        if let index = selectedIndex, index < sectors.count,
           let action = sectors[index].action {
            Task {
                await action.execute()
            }
        }
    }
}
