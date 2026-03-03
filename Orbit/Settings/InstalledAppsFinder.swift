import AppKit

struct InstalledApp: Identifiable {
    let bundleId: String
    let name: String
    let icon: NSImage
    var id: String { bundleId }
}

enum InstalledAppsFinder {
    private static let searchPaths = [
        "/Applications",
        "/System/Applications",
        "/Applications/Utilities",
    ]

    static func findAll() -> [InstalledApp] {
        var seen = Set<String>()
        var apps: [InstalledApp] = []
        let fm = FileManager.default

        for dir in searchPaths {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for name in contents where name.hasSuffix(".app") {
                let path = "\(dir)/\(name)"
                guard let bundle = Bundle(path: path),
                      let bundleId = bundle.bundleIdentifier else { continue }

                guard !seen.contains(bundleId) else { continue }
                seen.insert(bundleId)

                let displayName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? name.replacingOccurrences(of: ".app", with: "")

                let icon = NSWorkspace.shared.icon(forFile: path)
                apps.append(InstalledApp(bundleId: bundleId, name: displayName, icon: icon))
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
