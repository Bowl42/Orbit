import AppKit
import SwiftUI

final class RadialMenuPanel: NSPanel {

    init() {
        // Increased contentRect to allow breathing room for shadows and scale animations
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        worksWhenModal = true

        collectionBehavior = [
            .fullScreenAuxiliary,
            .canJoinAllSpaces,
            .stationary,
        ]

        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func setContent<Content: View>(@ViewBuilder _ content: () -> Content) {
        let hostingView = NSHostingView(rootView: content().ignoresSafeArea())
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = hostingView
    }

    /// Shows the panel centered on the mouse and returns the actual center point
    /// (which may differ from the mouse if the panel was clamped to screen edges).
    @discardableResult
    func showAtMouseLocation() -> CGPoint {
        alphaValue = 1
        let mouse = NSEvent.mouseLocation
        let size = frame.size
        let origin = CGPoint(
            x: mouse.x - size.width / 2,
            y: mouse.y - size.height / 2
        )

        let finalOrigin: CGPoint
        if let screen = NSScreen.screens.first(where: {
            $0.frame.contains(NSPoint(x: mouse.x, y: mouse.y))
        }) ?? NSScreen.main {
            let vis = screen.visibleFrame
            finalOrigin = CGPoint(
                x: min(max(origin.x, vis.minX), vis.maxX - size.width),
                y: min(max(origin.y, vis.minY), vis.maxY - size.height),
            )
        } else {
            finalOrigin = origin
        }

        setFrameOrigin(finalOrigin)
        orderFront(nil)

        // Return the actual center of the panel after clamping
        return CGPoint(
            x: finalOrigin.x + size.width / 2,
            y: finalOrigin.y + size.height / 2
        )
    }

    func dismiss() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.orderOut(nil)
                self?.alphaValue = 1  // Reset for next show
            }
        })
    }
}
