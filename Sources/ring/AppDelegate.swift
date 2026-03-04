import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var mouseMonitor: MouseEventMonitor?
    private var permissionController: PermissionWindowController?
    private var settingsWindow: NSWindow?
    var ringController: RingWindowController?
    var quickActionsController: QuickActionsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[Ring] applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.accessory)

        ringController = RingWindowController()
        quickActionsController = QuickActionsWindowController()

        setupStatusItem()

        let perm = PermissionWindowController()
        perm.onGranted = { [weak self] in
            print("[Ring] permission granted, starting monitor")
            self?.startMonitoring()
        }
        perm.showIfNeeded()
        permissionController = perm
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = Bundle.main.image(forResource: "ring") {
            image.size = NSSize(width: 18, height: 18)
            statusItem?.button?.image = image
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Test Ring", action: #selector(showTestRing), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Configure Slots…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Ring", action: #selector(quit), keyEquivalent: "q"))

        // Make all items target self
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc func showTestRing() {
        let point = NSEvent.mouseLocation
        print("[Ring] showTestRing at \(point)")
        ringController?.show(at: point)
    }

    @objc func openSettings() {
        if let win = settingsWindow, win.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            win.makeKeyAndOrderFront(nil)
            return
        }
        guard let vm = ringController?.viewModel else { return }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Ring — Configure Slots"
        win.contentView = NSHostingView(rootView: SettingsView(viewModel: vm))
        win.center()
        win.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        settingsWindow = win
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        let monitor = MouseEventMonitor()
        monitor.onButton5 = { [weak self] point in self?.ringController?.toggle(at: point) }
        monitor.onButton4 = { _ in Self.lookupAtPointer() }
        monitor.start()
        mouseMonitor = monitor
    }

    private static func lookupAtPointer() {
        // Ctrl+Cmd+D = macOS "Look Up" — works on selected text or word under cursor
        let src = CGEventSource(stateID: .hidSystemState)
        for keyDown in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: 0x02, keyDown: keyDown)
            e?.flags = [.maskControl, .maskCommand]
            e?.post(tap: .cghidEventTap)
        }
    }
}
