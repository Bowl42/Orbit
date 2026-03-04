import CoreGraphics
import AppKit

class MouseEventMonitor {
    var onButton4: ((NSPoint) -> Void)?
    var onButton5: ((NSPoint) -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var nsMonitor: Any?

    static func hasPermission() -> Bool {
        AXIsProcessTrusted() || CGPreflightListenEventAccess()
    }

    func start() {
        print("[Ring] AXTrusted=\(AXIsProcessTrusted()) ListenAccess=\(CGPreflightListenEventAccess())")
        startEventTap()
        if tap == nil {
            startNSMonitor()   // fallback only if CGEventTap failed
        }
    }

    // MARK: - CGEventTap

    private func startEventTap() {
        let mask: CGEventMask = (1 << CGEventType.otherMouseDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        // Try annotated session tap first, fall back to plain session tap
        tap = CGEvent.tapCreate(tap: .cgAnnotatedSessionEventTap, place: .headInsertEventTap,
                                options: .listenOnly, eventsOfInterest: mask,
                                callback: cgCallback, userInfo: refcon)
            ?? CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                 options: .listenOnly, eventsOfInterest: mask,
                                 callback: cgCallback, userInfo: refcon)

        if let tap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("[Ring] CGEventTap started")
        } else {
            print("[Ring] CGEventTap failed — relying on NSEvent monitor")
        }
    }

    // MARK: - NSEvent fallback

    private func startNSMonitor() {
        nsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            let btn = event.buttonNumber
            print("[Ring] NSEvent buttonNumber: \(btn)")
            let loc = NSEvent.mouseLocation
            switch btn {
            case 3: self?.onButton4?(loc)
            case 4: self?.onButton5?(loc)
            default: break
            }
        }
        print("[Ring] NSEvent monitor \(nsMonitor == nil ? "failed" : "started")")
    }

    // MARK: - Re-enable / stop

    func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
            self.tap = nil; runLoopSource = nil
        }
        if let m = nsMonitor { NSEvent.removeMonitor(m); nsMonitor = nil }
    }

    deinit { stop() }
}

private func cgCallback(
    proxy: CGEventTapProxy, type: CGEventType,
    event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon {
            Unmanaged<MouseEventMonitor>.fromOpaque(refcon).takeUnretainedValue().reenable()
        }
        return nil
    }
    guard let refcon, type == .otherMouseDown else { return Unmanaged.passRetained(event) }

    let monitor = Unmanaged<MouseEventMonitor>.fromOpaque(refcon).takeUnretainedValue()
    let btn = event.getIntegerValueField(.mouseEventButtonNumber)
    print("[Ring] CGEvent buttonNumber: \(btn)")
    let loc = NSEvent.mouseLocation
    DispatchQueue.main.async {
        switch btn {
        case 3: monitor.onButton4?(loc)
        case 4: monitor.onButton5?(loc)
        default: break
        }
    }
    return Unmanaged.passRetained(event)
}
