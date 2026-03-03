import Carbon.HIToolbox
import CoreGraphics

/// Represents a trigger combination — either a keyboard key + modifiers, or a mouse button + optional modifiers.
struct KeyCombo: Equatable, Sendable {
    enum TriggerType: Equatable, Sendable {
        case keyboard(keyCode: Int64)
        case mouseButton(number: Int64)  // CGEvent button number: 2=middle, 3=mouse4, 4=mouse5
    }

    let trigger: TriggerType
    let modifiers: CGEventFlags

    static let keyCodes: [String: Int64] = [
        "space": Int64(kVK_Space),
        "return": Int64(kVK_Return),
        "tab": Int64(kVK_Tab),
        "escape": Int64(kVK_Escape),
        "a": Int64(kVK_ANSI_A), "b": Int64(kVK_ANSI_B), "c": Int64(kVK_ANSI_C),
        "d": Int64(kVK_ANSI_D), "e": Int64(kVK_ANSI_E), "f": Int64(kVK_ANSI_F),
        "g": Int64(kVK_ANSI_G), "h": Int64(kVK_ANSI_H), "i": Int64(kVK_ANSI_I),
        "j": Int64(kVK_ANSI_J), "k": Int64(kVK_ANSI_K), "l": Int64(kVK_ANSI_L),
        "m": Int64(kVK_ANSI_M), "n": Int64(kVK_ANSI_N), "o": Int64(kVK_ANSI_O),
        "p": Int64(kVK_ANSI_P), "q": Int64(kVK_ANSI_Q), "r": Int64(kVK_ANSI_R),
        "s": Int64(kVK_ANSI_S), "t": Int64(kVK_ANSI_T), "u": Int64(kVK_ANSI_U),
        "v": Int64(kVK_ANSI_V), "w": Int64(kVK_ANSI_W), "x": Int64(kVK_ANSI_X),
        "y": Int64(kVK_ANSI_Y), "z": Int64(kVK_ANSI_Z),
    ]

    static let modifierMap: [String: CGEventFlags] = [
        "command": .maskCommand,
        "shift": .maskShift,
        "option": .maskAlternate,
        "control": .maskControl,
    ]

    init(key: String, modifiers: [String]) {
        let mods = modifiers.reduce(CGEventFlags()) { result, mod in
            result.union(KeyCombo.modifierMap[mod.lowercased()] ?? [])
        }
        self.modifiers = mods

        // Check if it's a mouse button trigger
        switch key.lowercased() {
        case "mouse3": self.trigger = .mouseButton(number: 2)
        case "mouse4": self.trigger = .mouseButton(number: 3)
        case "mouse5": self.trigger = .mouseButton(number: 4)
        default:
            let code = KeyCombo.keyCodes[key.lowercased()] ?? Int64(kVK_Space)
            self.trigger = .keyboard(keyCode: code)
        }
    }

    init(from config: OrbitConfig.HotkeyConfig) {
        self.init(key: config.key, modifiers: config.modifiers)
    }

    var isMouseTrigger: Bool {
        if case .mouseButton = trigger { return true }
        return false
    }

    // MARK: - Keyboard matching

    func matchesKeyDown(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard case .keyboard(let code) = trigger else { return false }
        return keyCode == code && flags.contains(modifiers)
    }

    func matchesKeyUp(keyCode: Int64) -> Bool {
        guard case .keyboard(let code) = trigger else { return false }
        return keyCode == code
    }

    func modifiersMatch(flags: CGEventFlags) -> Bool {
        guard !modifiers.isEmpty else { return true }
        return flags.contains(modifiers)
    }

    // MARK: - Mouse matching

    func matchesMouseDown(buttonNumber: Int64, flags: CGEventFlags) -> Bool {
        guard case .mouseButton(let number) = trigger else { return false }
        guard buttonNumber == number else { return false }
        if modifiers.isEmpty { return true }
        return flags.contains(modifiers)
    }

    func matchesMouseUp(buttonNumber: Int64) -> Bool {
        guard case .mouseButton(let number) = trigger else { return false }
        return buttonNumber == number
    }

    // MARK: - Display

    var displayName: String {
        var parts: [String] = []
        if modifiers.contains(.maskControl) { parts.append("Ctrl") }
        if modifiers.contains(.maskAlternate) { parts.append("Opt") }
        if modifiers.contains(.maskShift) { parts.append("Shift") }
        if modifiers.contains(.maskCommand) { parts.append("Cmd") }

        switch trigger {
        case .keyboard(let code):
            let keyName = KeyCombo.keyCodes.first { $0.value == code }?.key.capitalized ?? "?"
            parts.append(keyName)
        case .mouseButton(let num):
            parts.append("Mouse\(num + 1)")  // display as Mouse4, Mouse5 etc.
        }

        return parts.joined(separator: "+")
    }
}
