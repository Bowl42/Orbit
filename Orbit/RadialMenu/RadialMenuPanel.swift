import AppKit
import SwiftUI

final class RadialMenuPanel: NSPanel {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 340),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        worksWhenModal = true
        acceptsMouseMovedEvents = true

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

    @MainActor
    func setContent<Content: View>(@ViewBuilder _ content: () -> Content) {
        // 使用与设置窗口一致的 fullScreenUI 材质
        let effectView = NSVisualEffectView()
        effectView.material = .fullScreenUI 
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 170
        effectView.layer?.masksToBounds = true
        
        let hostingView = NSHostingView(rootView: content().ignoresSafeArea())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        effectView.addSubview(hostingView)
        self.contentView = effectView

        NSLayoutConstraint.activate([
            hostingView.centerXAnchor.constraint(equalTo: effectView.centerXAnchor),
            hostingView.centerYAnchor.constraint(equalTo: effectView.centerYAnchor),
            hostingView.widthAnchor.constraint(equalToConstant: 340),
            hostingView.heightAnchor.constraint(equalToConstant: 340)
        ])
    }

    @MainActor
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
                y: min(max(origin.y, vis.minY), vis.maxY - size.height)
            )
        } else {
            finalOrigin = origin
        }

        setFrameOrigin(finalOrigin)
        orderFront(nil)

        return CGPoint(
            x: finalOrigin.x + size.width / 2,
            y: finalOrigin.y + size.height / 2
        )
    }

    @MainActor
    func dismiss() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.orderOut(nil)
                self?.alphaValue = 1
            }
        })
    }
}
