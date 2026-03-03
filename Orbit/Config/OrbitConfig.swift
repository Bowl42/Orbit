import Foundation

struct OrbitConfig: Codable, Equatable, Sendable {
    var hotkey: HotkeyConfig
    var sectorCount: Int
    var sectors: [SectorConfig]

    struct HotkeyConfig: Codable, Equatable, Sendable {
        var key: String          // e.g. "space"
        var modifiers: [String]  // e.g. ["control"]
    }

    enum SectorConfig: Codable, Equatable, Sendable {
        case recent(index: Int)
        case pinned(bundleId: String, name: String, icon: IconConfig?)

        enum CodingKeys: String, CodingKey {
            case type, index, bundleId, name, icon
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
            }
        }
    }

    static let `default` = OrbitConfig(
        hotkey: HotkeyConfig(key: "space", modifiers: ["control"]),
        sectorCount: 8,
        sectors: (0..<8).map { .recent(index: $0) }
    )
}
