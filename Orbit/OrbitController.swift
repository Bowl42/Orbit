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
            MainActor.assumeIsolated { self?.showMenu() }
        }
        hotkeyManager.onHotkeyUp = { [weak self] in
            MainActor.assumeIsolated { self?.hideMenuAndExecute() }
        }
    }

    func startListening() {
        _ = hotkeyManager.start()
    }

    func stopListening() {
        hotkeyManager.stop()
    }

    func toggleListening() {
        if hotkeyManager.isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    private func showMenu() {
        // Build sectors first
        viewModel.buildSectors(
            config: configManager.config,
            recentApps: recentAppsTracker.topRecent(configManager.config.sectorCount)
        )
        viewModel.selectedIndex = nil
        
        // Setup panel
        let panel = RadialMenuPanel()
        panel.setContent {
            RadialMenuView(viewModel: self.viewModel)
        }
        
        // Capture exact center point in screen coordinates
        let actualCenter = panel.showAtMouseLocation()
        viewModel.centerPoint = actualCenter
        self.panel = panel
    }

    private func hideMenuAndExecute() {
        let selectedIndex = viewModel.selectedIndex
        let sectors = viewModel.sectors

        // 1. Dismiss panel
        panel?.dismiss()
        panel = nil

        // 2. Execute action
        if let index = selectedIndex, index < sectors.count, let action = sectors[index].action {
            Task {
                await action.execute()
            }
        }
        
        // 3. Reset VM state
        viewModel.selectedIndex = nil
    }
}
