import Carbon.HIToolbox
import CoreGraphics

struct KeyCombo: Equatable, Sendable {
    let keyCode: Int64
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
        self.keyCode = KeyCombo.keyCodes[key.lowercased()] ?? Int64(kVK_Space)
        self.modifiers = modifiers.reduce(CGEventFlags()) { result, mod in
            result.union(KeyCombo.modifierMap[mod.lowercased()] ?? [])
        }
    }

    init(from config: OrbitConfig.HotkeyConfig) {
        self.init(key: config.key, modifiers: config.modifiers)
    }

    func matches(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard keyCode == self.keyCode else { return false }
        return flags.contains(modifiers)
    }

    func modifiersMatch(flags: CGEventFlags) -> Bool {
        return flags.contains(modifiers)
    }
}
