import CoreGraphics
import AppKit

class MouseEventMonitor {
    var onButton4: ((NSPoint) -> Void)?
    var onButton5: ((NSPoint) -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var nsMonitor: Any?

    static func hasPermission() -> Bool {
        let mask: CGEventMask = 1 << CGEventType.otherMouseDown.rawValue
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .listenOnly, eventsOfInterest: mask,
            callback: { _, _, e, _ in Unmanaged.passUnretained(e) },
            userInfo: nil
        ) else { return false }
        CFMachPortInvalidate(tap)
        return true
    }

    func start() {
        let mask: CGEventMask = 1 << CGEventType.otherMouseDown.rawValue
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap, place: .headInsertEventTap,
            options: .listenOnly, eventsOfInterest: mask,
            callback: cgCallback, userInfo: refcon)
            ?? CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .listenOnly, eventsOfInterest: mask,
            callback: cgCallback, userInfo: refcon)

        if let tap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            log("[Ring] CGEventTap started")
        } else {
            log("[Ring] CGEventTap failed — falling back to NSEvent monitor")
            startNSMonitor()
        }
    }

    private func startNSMonitor() {
        nsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            let btn = event.buttonNumber
            let loc = NSEvent.mouseLocation
            switch btn {
            case 3: self?.onButton4?(loc)
            case 4: self?.onButton5?(loc)
            default: break
            }
        }
        log("[Ring] NSEvent monitor \(nsMonitor == nil ? "FAILED" : "started")")
    }

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
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<MouseEventMonitor>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        monitor.reenable()
        return nil
    }
    guard type == .otherMouseDown else { return Unmanaged.passUnretained(event) }

    let btn = event.getIntegerValueField(.mouseEventButtonNumber)
    let loc = NSEvent.mouseLocation
    log("[Ring] CGEvent otherMouseDown btn=\(btn)")
    DispatchQueue.main.async {
        switch btn {
        case 3: monitor.onButton4?(loc)
        case 4: monitor.onButton5?(loc)
        default: break
        }
    }
    return Unmanaged.passUnretained(event)
}
