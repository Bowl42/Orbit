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
    private var globalMonitor: Any?
    private var localMonitor: Any?

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
        
        // 1. Capture exact center point in screen coordinates
        let actualCenter = panel.showAtMouseLocation()
        viewModel.centerPoint = actualCenter
        self.panel = panel

        // 2. Clear old monitors if they exist
        clearMonitors()

        // 3. Add new monitors - capture self weakly but run safely on MainActor
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.viewModel.updateSelection(mouseLocation: NSEvent.mouseLocation)
            }
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            guard let self else { return event }
            Task { @MainActor in
                self.viewModel.updateSelection(mouseLocation: NSEvent.mouseLocation)
            }
            return event
        }
    }

    private func hideMenuAndExecute() {
        let selectedIndex = viewModel.selectedIndex
        let sectors = viewModel.sectors

        // 1. Clear monitors immediately
        clearMonitors()

        // 2. Dismiss panel
        panel?.dismiss()
        panel = nil

        // 3. Execute action asynchronously
        if let index = selectedIndex, index < sectors.count, let action = sectors[index].action {
            Task {
                await action.execute()
            }
        }
        
        // 4. Reset VM state
        viewModel.selectedIndex = nil
    }

    private func clearMonitors() {
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
            globalMonitor = nil
        }
        if let lm = localMonitor {
            NSEvent.removeMonitor(lm)
            localMonitor = nil
        }
    }
}
