import Foundation

@MainActor
@Observable
final class ConfigManager {
    var config: OrbitConfig

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("Orbit", isDirectory: true)

        self.fileURL = appSupport.appendingPathComponent("config.json")
        self.config = .default

        loadConfig()
    }

    func loadConfig() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            saveConfig()
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            config = try JSONDecoder().decode(OrbitConfig.self, from: data)
        } catch {
            print("Failed to load config, using defaults: \(error)")
            config = .default
        }
    }

    func saveConfig() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save config: \(error)")
        }
    }
}
