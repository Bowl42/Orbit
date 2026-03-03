import AppKit

enum ActionIcon: Sendable {
    case appIcon(bundleId: String)
    case sfSymbol(name: String)

    @MainActor
    var nsImage: NSImage? {
        switch self {
        case .appIcon(let bundleId):
            guard let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleId
            ) else { return nil }
            return NSWorkspace.shared.icon(forFile: url.path)
        case .sfSymbol(let name):
            return NSImage(systemSymbolName: name, accessibilityDescription: nil)
        }
    }
}

protocol OrbitAction: Sendable {
    var id: String { get }
    var name: String { get }
    var icon: ActionIcon { get }
    var subtitle: String? { get }
    func execute() async
}
