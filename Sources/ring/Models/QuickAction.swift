import AppKit
import CoreGraphics

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String  // SF Symbol
    let perform: () -> Void

    static var all: [QuickAction] {[
        QuickAction(title: "Look Up", icon: "text.magnifyingglass") {
            // Ctrl+Cmd+D triggers the macOS dictionary lookup popup
            sendKey(virtualKey: 0x02, flags: [.maskControl, .maskCommand])
        },
        QuickAction(title: "Copy", icon: "doc.on.doc") {
            NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
        },
        QuickAction(title: "Paste", icon: "doc.on.clipboard") {
            NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
        },
        QuickAction(title: "Screenshot", icon: "camera.viewfinder") {
            let url = URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app")
            NSWorkspace.shared.open(url)
        },
    ]}
}

private func sendKey(virtualKey: CGKeyCode, flags: CGEventFlags) {
    let src = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: true)
    down?.flags = flags
    down?.post(tap: .cghidEventTap)
    let up = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: false)
    up?.flags = flags
    up?.post(tap: .cghidEventTap)
}
