import AppKit
import SwiftUI

class PermissionWindowController {
    private var window: NSWindow?
    private var observer: NSObjectProtocol?
    private var pollTimer: Timer?
    var onGranted: (() -> Void)?

    func showIfNeeded() {
        if MouseEventMonitor.hasPermission() {
            print("[Ring] Input Monitoring permission available — starting monitor")
            onGranted?()
            return
        }
        print("[Ring] Input Monitoring not available — showing permission window")
        showWindow()
        startPolling()
    }

    private func showWindow() {
        // Attempting tapCreate is what causes macOS to register the app
        // in System Settings → Privacy & Security → Input Monitoring
        registerInInputMonitoringList()

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

    // macOS registers the app in the Input Monitoring list the first time
    // it attempts to create an event tap — even if the tap returns nil.
    private func registerInInputMonitoringList() {
        let mask: CGEventMask = (1 << CGEventType.otherMouseDown.rawValue)
        if let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, _ in Unmanaged.passRetained(event) },
            userInfo: nil
        ) {
            CFMachPortInvalidate(tap)
        }
    }

    // Poll every second — reliable across all macOS versions
    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            if MouseEventMonitor.hasPermission() {
                print("[Ring] Input Monitoring granted (poll)")
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
