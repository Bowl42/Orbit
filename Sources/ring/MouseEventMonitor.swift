import CoreGraphics
import AppKit

class MouseEventMonitor {
    var onButton4: ((NSPoint) -> Void)?
    var onButton5: ((NSPoint) -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var nsMonitor: Any?

    // Deduplicate events that arrive from both CGEventTap and NSEvent monitor
    private var lastFired = [Int64: Date]()
    private let dedupInterval: TimeInterval = 0.05

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
        startEventTap()
        startNSMonitor()   // always run both — NSEvent covers when CGEventTap is disabled
    }

    // Called from both paths; deduplicates rapid double-fires
    func handle(btn: Int64, loc: NSPoint) {
        let now = Date()
        if let last = lastFired[btn], now.timeIntervalSince(last) < dedupInterval { return }
        lastFired[btn] = now
        switch btn {
        case 3: onButton4?(loc)
        case 4: onButton5?(loc)
        default: break
        }
    }

    // MARK: - CGEventTap

    private func startEventTap() {
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
            log("[Ring] CGEventTap failed — NSEvent monitor will handle events")
        }
    }

    // MARK: - NSEvent monitor (global — fires when other apps receive events)

    private func startNSMonitor() {
        nsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            guard let self else { return }
            let btn = Int64(event.buttonNumber)
            let loc = NSEvent.mouseLocation
            self.handle(btn: btn, loc: loc)
        }
        log("[Ring] NSEvent monitor \(nsMonitor == nil ? "FAILED" : "started")")
    }

    // MARK: - Reenable / stop

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
        log("[Ring] CGEventTap disabled — reenabling")
        monitor.reenable()
        return nil
    }
    guard type == .otherMouseDown else { return Unmanaged.passUnretained(event) }

    let btn = event.getIntegerValueField(.mouseEventButtonNumber)
    let loc = NSEvent.mouseLocation
    log("[Ring] CGEvent btn=\(btn)")
    DispatchQueue.main.async { monitor.handle(btn: btn, loc: loc) }
    return Unmanaged.passUnretained(event)
}
