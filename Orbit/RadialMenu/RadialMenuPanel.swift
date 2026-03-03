import AppKit
import SwiftUI

final class RadialMenuPanel: NSPanel {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 320),
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
        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 160 // half of 320
        effectView.layer?.masksToBounds = true
        effectView.translatesAutoresizingMaskIntoConstraints = false

        let hostingView = NSHostingView(rootView: content().ignoresSafeArea())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(hostingView)

        self.contentView = effectView

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: effectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
        ])
    }

    func showAtMouseLocation() {
        let mouse = NSEvent.mouseLocation
        let size = frame.size
        let origin = CGPoint(
            x: mouse.x - size.width / 2,
            y: mouse.y - size.height / 2
        )

        if let screen = NSScreen.screens.first(where: {
            $0.frame.contains(NSPoint(x: mouse.x, y: mouse.y))
        }) ?? NSScreen.main {
            let vis = screen.visibleFrame
            let clamped = CGPoint(
                x: min(max(origin.x, vis.minX), vis.maxX - size.width),
                y: min(max(origin.y, vis.minY), vis.maxY - size.height),
            )
            setFrameOrigin(clamped)
        } else {
            setFrameOrigin(origin)
        }

        orderFront(nil)
    }

    func dismiss() {
        orderOut(nil)
    }
}
