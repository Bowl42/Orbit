import CoreGraphics
import AppKit

/// Callback must be a free function for CGEvent tap C bridge.
private func hotkeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let userInfo {
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            if let port = manager.eventTapPort {
                CGEvent.tapEnable(tap: port, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    switch type {
    case .keyDown:
        manager.handleKeyDown(keyCode: keyCode, flags: flags)
    case .keyUp:
        manager.handleKeyUp(keyCode: keyCode, flags: flags)
    case .flagsChanged:
        manager.handleFlagsChanged(keyCode: keyCode, flags: flags)
    default:
        break
    }

    return Unmanaged.passUnretained(event)
}

/// Manages global hotkey detection using a CGEvent tap in listen-only mode.
///
/// This class is intentionally NOT `@MainActor` because the CGEvent tap callback
/// is a C function pointer that cannot be actor-isolated. The callback accesses
/// the manager instance through an `Unmanaged` opaque pointer. The class is marked
/// `@unchecked Sendable` because we manage thread safety manually -- the event tap
/// runs on the main run loop, and closure callbacks are dispatched to the main thread.
@Observable
final class HotkeyManager: @unchecked Sendable {
    fileprivate var eventTapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthCheckTimer: Timer?

    var keyCombo: KeyCombo = KeyCombo(key: "space", modifiers: ["control"])
    private(set) var isHotkeyHeld = false

    var onHotkeyDown: (@Sendable () -> Void)?
    var onHotkeyUp: (@Sendable () -> Void)?

    static func hasPermission() -> Bool {
        CGPreflightListenEventAccess()
    }

    static func requestPermission() {
        CGRequestListenEventAccess()
    }

    @discardableResult
    func start() -> Bool {
        guard HotkeyManager.hasPermission() else {
            HotkeyManager.requestPermission()
            return false
        }

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: hotkeyEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create CGEvent tap")
            return false
        }

        eventTapPort = port

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            print("Failed to create run loop source")
            return false
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)

        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self, let port = self.eventTapPort else { return }
            if !CGEvent.tapIsEnabled(tap: port) {
                CGEvent.tapEnable(tap: port, enable: true)
            }
        }

        return true
    }

    func stop() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil

        if let port = eventTapPort {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        eventTapPort = nil
        runLoopSource = nil
    }

    fileprivate func handleKeyDown(keyCode: Int64, flags: CGEventFlags) {
        if !isHotkeyHeld && keyCombo.matches(keyCode: keyCode, flags: flags) {
            isHotkeyHeld = true
            let callback = onHotkeyDown
            DispatchQueue.main.async {
                callback?()
            }
        }

        if isHotkeyHeld && keyCode == 53 /* kVK_Escape */ {
            isHotkeyHeld = false
            let callback = onHotkeyUp
            DispatchQueue.main.async {
                callback?()
            }
        }
    }

    fileprivate func handleKeyUp(keyCode: Int64, flags: CGEventFlags) {
        if isHotkeyHeld && keyCode == keyCombo.keyCode {
            isHotkeyHeld = false
            let callback = onHotkeyUp
            DispatchQueue.main.async {
                callback?()
            }
        }
    }

    fileprivate func handleFlagsChanged(keyCode: Int64, flags: CGEventFlags) {
        if isHotkeyHeld && !keyCombo.modifiersMatch(flags: flags) {
            isHotkeyHeld = false
            let callback = onHotkeyUp
            DispatchQueue.main.async {
                callback?()
            }
        }
    }
}
