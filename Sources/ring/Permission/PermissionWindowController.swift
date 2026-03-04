import AppKit
import SwiftUI

class PermissionWindowController {
    private var window: NSWindow?
    private var observer: NSObjectProtocol?
    private var pollTimer: Timer?
    var onGranted: (() -> Void)?

    func showIfNeeded() {
        if MouseEventMonitor.hasPermission() {
            log("[Ring] Input Monitoring permission available — starting monitor")
            onGranted?()
            return
        }
        log("[Ring] Input Monitoring not available — showing permission window")
        showWindow()
        startPolling()
    }

    private func showWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Ring — Permission Required"
        win.contentView = NSHostingView(rootView: PermissionView())
        win.center()
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = win
    }

    // Poll every second — reliable across all macOS versions
    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            if MouseEventMonitor.hasPermission() {
                log("[Ring] Input Monitoring granted (poll)")
                self?.granted()
            }
        }
    }

    private func granted() {
        dismiss()
        onGranted?()
    }

    private func dismiss() {
        pollTimer?.invalidate(); pollTimer = nil
        window?.close(); window = nil
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
            self.observer = nil
        }
    }
}
