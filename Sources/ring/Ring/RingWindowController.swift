import AppKit
import SwiftUI
import QuartzCore

class RingWindowController {
    private var window: NSPanel?
    private var outsideMonitor: Any?
    private var previousApp: NSRunningApplication?
    let viewModel = RingViewModel()

    var isVisible: Bool { window?.isVisible ?? false }

    func toggle(at point: NSPoint) {
        isVisible ? close() : show(at: point)
    }

    func show(at point: NSPoint) {
        log("[Ring] show() start")
        viewModel.refresh()
        log("[Ring] refresh done, slots: \(viewModel.slots.count)")
        previousApp = NSWorkspace.shared.frontmostApplication

        let size = CGSize(width: 280, height: 280)
        let origin = clampedOrigin(from: point, size: size)
        log("[Ring] origin: \(origin)")

        let w = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        log("[Ring] window created")
        w.isOpaque = false
        w.backgroundColor = .clear
        w.level = .floating
        w.animationBehavior = .none
        w.collectionBehavior = [.canJoinAllSpaces, .stationary]
        w.hasShadow = false
        log("[Ring] before NSHostingView")
        w.contentView = NSHostingView(
            rootView: RingView(
                viewModel: viewModel,
                onDismiss: { [weak self] in self?.close() },
                onActivate: { [weak self] slot in self?.activate(slot) }
            )
        )
        log("[Ring] before orderFront")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        w.orderFront(nil)
        CATransaction.commit()
        window = w
        log("[Ring] window shown")

        outsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            // button 4 (buttonNumber 3) is handled by toggle() via CGEventTap — don't double-close
            guard event.buttonNumber != 3 else { return }
            self?.close()
        }
    }

    func activate(_ slot: AppSlot) {
        // Close ring without restoring previousApp — slot.activate() takes focus
        window?.close()
        window = nil
        if let m = outsideMonitor { NSEvent.removeMonitor(m); outsideMonitor = nil }
        previousApp = nil
        slot.activate()
    }

    func close() {
        window?.close()
        window = nil
        if let m = outsideMonitor { NSEvent.removeMonitor(m); outsideMonitor = nil }
        previousApp?.activate(options: [.activateIgnoringOtherApps])
        previousApp = nil
    }

    private func clampedOrigin(from p: NSPoint, size: CGSize) -> NSPoint {
        var x = p.x - size.width / 2
        var y = p.y - size.height / 2
        let screen = NSScreen.screens.first { $0.frame.contains(p) } ?? NSScreen.main!
        x = max(screen.visibleFrame.minX, min(x, screen.visibleFrame.maxX - size.width))
        y = max(screen.visibleFrame.minY, min(y, screen.visibleFrame.maxY - size.height))
        return NSPoint(x: x, y: y)
    }
}

