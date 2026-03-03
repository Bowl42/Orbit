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

    private func setupHotkey() {
        let config = configManager.config
        hotkeyManager.keyCombo = KeyCombo(from: config.hotkey)

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
        viewModel.centerPoint = NSEvent.mouseLocation

        let panel = RadialMenuPanel()
        panel.setContent {
            RadialMenuView(viewModel: self.viewModel)
        }
        panel.showAtMouseLocation()
        self.panel = panel

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.viewModel.updateSelection(mouseLocation: NSEvent.mouseLocation)
            }
        }
    }

    private func hideMenuAndExecute() {
        if viewModel.selectedIndex != nil {
            Task {
                await viewModel.executeSelected()
            }
        }

        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        mouseMonitor = nil

        viewModel.isVisible = false
        viewModel.selectedIndex = nil
        panel?.dismiss()
        panel = nil
    }
}
