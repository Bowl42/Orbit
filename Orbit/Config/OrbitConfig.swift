import Foundation

struct OrbitConfig: Codable, Equatable, Sendable {
    var isActive: Bool
    var hotkey: HotkeyConfig
    var sectorCount: Int
    var sectors: [SectorConfig]

    struct HotkeyConfig: Codable, Equatable, Sendable {
        /// Trigger type: "keyboard" or "mouse"
        var type: String?        // nil defaults to "keyboard" for backwards compat
        /// For keyboard: key name (e.g. "space"). For mouse: "mouse4", "mouse5", etc.
        var key: String
        /// Modifier keys required (e.g. ["control"]). For mouse buttons, can be empty.
        var modifiers: [String]

        var isMouseTrigger: Bool {
            type == "mouse" || key.hasPrefix("mouse")
        }

        /// Mouse button number (0-indexed: mouse4 = button 3, mouse5 = button 4)
        var mouseButtonNumber: Int64? {
            switch key.lowercased() {
            case "mouse3": return 2  // middle click
            case "mouse4": return 3  // back/side button
            case "mouse5": return 4  // forward/side button
            default: return nil
            }
        }
    }

    enum SystemActionKind: String, Codable, CaseIterable, Equatable, Sendable {
        case lockScreen
        case toggleDnd
        case screenshot
        case sleepDisplay
        case emptyTrash

        var displayName: String {
            switch self {
            case .lockScreen: "Lock Screen"
            case .toggleDnd: "Toggle Do Not Disturb"
            case .screenshot: "Screenshot"
            case .sleepDisplay: "Sleep Display"
            case .emptyTrash: "Empty Trash"
            }
        }

        var sfSymbolName: String {
            switch self {
            case .lockScreen: "lock.fill"
            case .toggleDnd: "moon.fill"
            case .screenshot: "camera.viewfinder"
            case .sleepDisplay: "display"
            case .emptyTrash: "trash.fill"
            }
        }
    }

    enum SectorConfig: Codable, Equatable, Sendable {
        case recent(index: Int)
        case pinned(bundleId: String, name: String, icon: IconConfig?)
        case url(name: String, url: String, icon: IconConfig?)
        case shellCommand(name: String, command: String, icon: IconConfig?)
        case systemAction(action: SystemActionKind)
        case shortcut(name: String)
        case openPath(name: String, path: String, icon: IconConfig?)
        case translate

        enum CodingKeys: String, CodingKey {
            case type, index, bundleId, name, icon, url, command, action, path
        }

        struct IconConfig: Codable, Equatable, Sendable {
            var sfSymbol: String?
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "recent":
                let index = try container.decode(Int.self, forKey: .index)
                self = .recent(index: index)
            case "pinned":
                let bundleId = try container.decode(String.self, forKey: .bundleId)
                let name = try container.decode(String.self, forKey: .name)
                let icon = try container.decodeIfPresent(IconConfig.self, forKey: .icon)
                self = .pinned(bundleId: bundleId, name: name, icon: icon)
            case "url":
                let name = try container.decode(String.self, forKey: .name)
                let url = try container.decode(String.self, forKey: .url)
                let icon = try container.decodeIfPresent(IconConfig.self, forKey: .icon)
                self = .url(name: name, url: url, icon: icon)
            case "shellCommand":
                let name = try container.decode(String.self, forKey: .name)
                let command = try container.decode(String.self, forKey: .command)
                let icon = try container.decodeIfPresent(IconConfig.self, forKey: .icon)
                self = .shellCommand(name: name, command: command, icon: icon)
            case "systemAction":
                let action = try container.decode(SystemActionKind.self, forKey: .action)
                self = .systemAction(action: action)
            case "shortcut":
                let name = try container.decode(String.self, forKey: .name)
                self = .shortcut(name: name)
            case "openPath":
                let name = try container.decode(String.self, forKey: .name)
                let path = try container.decode(String.self, forKey: .path)
                let icon = try container.decodeIfPresent(IconConfig.self, forKey: .icon)
                self = .openPath(name: name, path: path, icon: icon)
            case "translate":
                self = .translate
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type, in: container,
                    debugDescription: "Unknown sector type: \(type)"
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .recent(let index):
                try container.encode("recent", forKey: .type)
                try container.encode(index, forKey: .index)
            case .pinned(let bundleId, let name, let icon):
                try container.encode("pinned", forKey: .type)
                try container.encode(bundleId, forKey: .bundleId)
                try container.encode(name, forKey: .name)
                try container.encodeIfPresent(icon, forKey: .icon)
            case .url(let name, let url, let icon):
                try container.encode("url", forKey: .type)
                try container.encode(name, forKey: .name)
                try container.encode(url, forKey: .url)
                try container.encodeIfPresent(icon, forKey: .icon)
            case .shellCommand(let name, let command, let icon):
                try container.encode("shellCommand", forKey: .type)
                try container.encode(name, forKey: .name)
                try container.encode(command, forKey: .command)
                try container.encodeIfPresent(icon, forKey: .icon)
            case .systemAction(let action):
                try container.encode("systemAction", forKey: .type)
                try container.encode(action, forKey: .action)
            case .shortcut(let name):
                try container.encode("shortcut", forKey: .type)
                try container.encode(name, forKey: .name)
            case .openPath(let name, let path, let icon):
                try container.encode("openPath", forKey: .type)
                try container.encode(name, forKey: .name)
                try container.encode(path, forKey: .path)
                try container.encodeIfPresent(icon, forKey: .icon)
            case .translate:
                try container.encode("translate", forKey: .type)
            }
        }
    }

    static let `default` = OrbitConfig(
        isActive: true,
        hotkey: HotkeyConfig(type: "mouse", key: "mouse4", modifiers: []),
        sectorCount: 8,
        sectors: (0..<8).map { .recent(index: $0) }
    )

    init(isActive: Bool, hotkey: HotkeyConfig, sectorCount: Int, sectors: [SectorConfig]) {
        self.isActive = isActive
        self.hotkey = hotkey
        self.sectorCount = sectorCount
        self.sectors = sectors
    }

    // Custom decoder so old configs without `isActive` default to true
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isActive = (try? c.decode(Bool.self, forKey: .isActive)) ?? true
        hotkey = try c.decode(HotkeyConfig.self, forKey: .hotkey)
        sectorCount = try c.decode(Int.self, forKey: .sectorCount)
        sectors = try c.decode([SectorConfig].self, forKey: .sectors)
    }

    private enum CodingKeys: String, CodingKey {
        case isActive, hotkey, sectorCount, sectors
    }
}
