import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, ObservableObject {
    @Published var controller: OrbitController?
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 始终保持为 accessory 模式，避免 Dock 图标闪烁和由于窗口关闭导致的退出
        NSApp.setActivationPolicy(.accessory)
        
        // 显式设置自己为 NSApp 的代理，确保生命周期回调生效
        NSApp.delegate = self

        controller = OrbitController()

        if HotkeyManager.hasPermission() {
            controller?.startListening()
        } else {
            showSettings()
        }
    }

    // 关键：返回 false 确保应用在所有窗口关闭后依然运行
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func showSettings() {
        if let existing = settingsWindow {
            if !existing.isVisible {
                existing.makeKeyAndOrderFront(nil)
            }
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let controller else { return }

        let settingsView = SettingsView(
            configManager: controller.configManager,
            onSave: { [weak self] in
                guard let self, let controller = self.controller else { return }
                controller.applyHotkey()
                if controller.configManager.config.isActive && HotkeyManager.hasPermission() {
                    if !controller.hotkeyManager.isListening {
                        controller.startListening()
                    }
                } else {
                    controller.stopListening()
                }
            }
        )

        let hostingView = NSHostingView(rootView: settingsView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 720),
            styleMask: [.titled, .closable, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Orbit Settings"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.contentView = hostingView
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false // 关键：关闭时不销毁对象，由 settingsWindow 变量持有
        
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        // 仅仅是将引用设为 nil，不再执行复杂的激活策略切换
        settingsWindow = nil
    }
}
