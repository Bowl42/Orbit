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
    case .otherMouseDown:
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        manager.handleMouseDown(button: button, flags: flags)
    case .otherMouseUp:
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        manager.handleMouseUp(button: button, flags: flags)
    default:
        break
    }

    return Unmanaged.passUnretained(event)
}

/// Manages global hotkey detection using a CGEvent tap in listen-only mode.
///
/// Supports both keyboard shortcuts (e.g. Ctrl+Space) and mouse buttons
/// (e.g. Mouse4/Mouse5 side buttons on Logitech/other multi-button mice).
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

        // Build event mask based on trigger type
        var eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        // Always include mouse events so we can switch trigger type at runtime
        eventMask |= (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.otherMouseUp.rawValue)

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

    // MARK: - Keyboard event handlers

    fileprivate func handleKeyDown(keyCode: Int64, flags: CGEventFlags) {
        if !isHotkeyHeld && keyCombo.matchesKeyDown(keyCode: keyCode, flags: flags) {
            isHotkeyHeld = true
            let callback = onHotkeyDown
            DispatchQueue.main.async {
                callback?()
            }
        }

        // Esc cancels while menu is shown
        if isHotkeyHeld && keyCode == 53 /* kVK_Escape */ {
            isHotkeyHeld = false
            let callback = onHotkeyUp
            DispatchQueue.main.async {
                callback?()
            }
        }
    }

    fileprivate func handleKeyUp(keyCode: Int64, flags: CGEventFlags) {
        if isHotkeyHeld && keyCombo.matchesKeyUp(keyCode: keyCode) {
            isHotkeyHeld = false
            let callback = onHotkeyUp
            DispatchQueue.main.async {
                callback?()
            }
        }
    }

    fileprivate func handleFlagsChanged(keyCode: Int64, flags: CGEventFlags) {
        // Only relevant for keyboard triggers with modifiers
        if isHotkeyHeld && !keyCombo.isMouseTrigger && !keyCombo.modifiersMatch(flags: flags) {
            isHotkeyHeld = false
            let callback = onHotkeyUp
            DispatchQueue.main.async {
                callback?()
            }
        }
    }

    // MARK: - Mouse event handlers

    fileprivate func handleMouseDown(button: Int64, flags: CGEventFlags) {
        if !isHotkeyHeld && keyCombo.matchesMouseDown(buttonNumber: button, flags: flags) {
            isHotkeyHeld = true
            let callback = onHotkeyDown
            DispatchQueue.main.async {
                callback?()
            }
        }
    }

    fileprivate func handleMouseUp(button: Int64, flags: CGEventFlags) {
        if isHotkeyHeld && keyCombo.matchesMouseUp(buttonNumber: button) {
            isHotkeyHeld = false
            let callback = onHotkeyUp
            DispatchQueue.main.async {
                callback?()
            }
        }
    }
}
