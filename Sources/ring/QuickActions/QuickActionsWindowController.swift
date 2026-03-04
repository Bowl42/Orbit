import AppKit
import SwiftUI
import QuartzCore

class QuickActionsWindowController {
    private var panel: NSPanel?
    private var outsideMonitor: Any?

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(at screenPoint: NSPoint) {
        if isVisible { close(); return }

        let size = CGSize(width: 192, height: 180)
        let origin = clampedOrigin(from: screenPoint, size: size)

        let p = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .floating
        p.animationBehavior = .none
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.isMovable = false
        p.hasShadow = false

        let rootView = QuickActionsView(onDismiss: { [weak self] in self?.close() })
        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = NSRect(origin: .zero, size: size)
        p.contentView = hosting
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        p.orderFront(nil)
        CATransaction.commit()
        panel = p

        outsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in self?.close() }
    }

    func close() {
        panel?.close()
        panel = nil
        if let m = outsideMonitor { NSEvent.removeMonitor(m); outsideMonitor = nil }
    }

    // Appear just above-right of the cursor
    private func clampedOrigin(from p: NSPoint, size: CGSize) -> NSPoint {
        var x = p.x + 4
        var y = p.y - size.height - 4
        let screen = NSScreen.screens.first(where: { $0.frame.contains(p) }) ?? NSScreen.main
        if let screen {
            x = max(screen.visibleFrame.minX, min(x, screen.visibleFrame.maxX - size.width))
            y = max(screen.visibleFrame.minY, min(y, screen.visibleFrame.maxY - size.height))
        }
        return NSPoint(x: x, y: y)
    }
}
