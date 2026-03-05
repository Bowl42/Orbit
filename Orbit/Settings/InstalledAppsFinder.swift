import AppKit

struct InstalledApp: Identifiable, Sendable {
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

    static func findAll() async -> [InstalledApp] {
        return await Task.detached(priority: .userInitiated) {
            var seen = Set<String>()
            var apps: [InstalledApp] = []
            let fm = FileManager.default

            for dir in searchPaths {
                guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
                for name in contents where name.hasSuffix(".app") {
                    let path = "\(dir)/\(name)"
                    
                    // Use standard Bundle to get identifiers, but avoid deep scanning
                    guard let bundle = Bundle(path: path),
                          let bundleId = bundle.bundleIdentifier else { continue }

                    guard !seen.contains(bundleId) else { continue }
                    seen.insert(bundleId)

                    let displayName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                        ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                        ?? name.replacingOccurrences(of: ".app", with: "")

                    // NSWorkspace.shared.icon is generally fast as it uses cached system icons
                    let icon = NSWorkspace.shared.icon(forFile: path)
                    apps.append(InstalledApp(bundleId: bundleId, name: displayName, icon: icon))
                }
            }

            return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }.value
    }
}
