import Foundation
import AppKit

@MainActor
@Observable
final class RadialMenuViewModel {
    var sectors: [SectorItem] = []
    var selectedIndex: Int? = nil
    var isVisible: Bool = false

    /// Center of the panel in screen coordinates.
    var centerPoint: CGPoint = .zero

    private let deadZoneRadius: CGFloat = 30
    private let outerBoundaryRadius: CGFloat = 170

    struct SectorItem: Identifiable {
        let id: String
        let name: String
        let icon: NSImage?
        let action: (any OrbitAction)?
    }

    /// Calculate which sector the mouse is pointing at.
    func updateSelection(mouseLocation: CGPoint) {
        let dx = mouseLocation.x - centerPoint.x
        let dy = mouseLocation.y - centerPoint.y
        let distance = sqrt(dx * dx + dy * dy)

        // 1. 死区检查 (Deadzone check)
        // If mouse is too close to center, clear selection
        guard distance > deadZoneRadius else {
            selectedIndex = nil
            return
        }

        // 2. Outer boundary check - cancel if mouse is too far
        guard distance < outerBoundaryRadius else {
            selectedIndex = nil
            return
        }

        guard !sectors.isEmpty else {
            selectedIndex = nil
            return
        }

        // 3. 角度计算 (Angle calculation)
        // Screen Y is bottom-up, atan2(dy, dx) gives angle from X-axis.
        var angle = atan2(dy, dx)
        
        // Convert to 0-360 starting from 12 o'clock (top) clockwise.
        // atan2 is 0 at right, pi/2 at top.
        // We want 0 at top.
        angle = -(angle - .pi / 2) 
        if angle < 0 { angle += 2 * .pi }

        let sectorAngle = (2 * .pi) / CGFloat(sectors.count)
        
        // 4. 关键修正：偏移半个扇区角度，使第 0 个扇区的中心对准 0 度（正上方）
        let index = Int((angle + sectorAngle / 2) / sectorAngle) % sectors.count

        selectedIndex = index
    }

    private func resolveIcon(iconConfig: OrbitConfig.SectorConfig.IconConfig?, fallback: ActionIcon) -> NSImage? {
        if let sf = iconConfig?.sfSymbol {
            return NSImage(systemSymbolName: sf, accessibilityDescription: nil)
        }
        return fallback.nsImage
    }

    func buildSectors(config: OrbitConfig, recentApps: [RecentAppsTracker.AppInfo]) {
        var recentIndex = 0
        var items: [SectorItem] = []

        for sectorConfig in config.sectors.prefix(config.sectorCount) {
            switch sectorConfig {
            case .recent:
                if recentIndex < recentApps.count {
                    let app = recentApps[recentIndex]
                    let action = LaunchAppAction(id: app.id, name: app.name, bundleIdentifier: app.id)
                    items.append(SectorItem(id: "recent-\(recentIndex)", name: app.name, icon: app.icon, action: action))
                } else {
                    items.append(SectorItem(id: "empty-\(recentIndex)", name: "Empty", icon: NSImage(systemSymbolName: "circle.dashed", accessibilityDescription: nil), action: nil))
                }
                recentIndex += 1
            case .pinned(let bundleId, let name, let iconConfig):
                let action = LaunchAppAction(id: bundleId, name: name, bundleIdentifier: bundleId)
                items.append(SectorItem(id: "pinned-\(bundleId)", name: name, icon: resolveIcon(iconConfig: iconConfig, fallback: action.icon), action: action))
            case .url(let name, let urlString, let iconConfig):
                let action = OpenURLAction(id: "url-\(urlString)", name: name, urlString: urlString)
                items.append(SectorItem(id: "url-\(urlString)", name: name, icon: resolveIcon(iconConfig: iconConfig, fallback: action.icon), action: action))
            case .shellCommand(let name, let command, let iconConfig):
                let action = ShellCommandAction(id: "shell-\(name)", name: name, command: command)
                items.append(SectorItem(id: "shell-\(name)", name: name, icon: resolveIcon(iconConfig: iconConfig, fallback: action.icon), action: action))
            case .systemAction(let kind):
                let action = SystemAction(id: "system-\(kind.rawValue)", kind: kind)
                items.append(SectorItem(id: "system-\(kind.rawValue)", name: kind.displayName, icon: resolveIcon(iconConfig: nil, fallback: action.icon), action: action))
            case .shortcut(let name):
                let action = RunShortcutAction(id: "shortcut-\(name)", name: name)
                items.append(SectorItem(id: "shortcut-\(name)", name: name, icon: resolveIcon(iconConfig: nil, fallback: action.icon), action: action))
            case .openPath(let name, let path, let iconConfig):
                let action = OpenPathAction(id: "path-\(path)", name: name, path: path)
                items.append(SectorItem(id: "path-\(path)", name: name, icon: resolveIcon(iconConfig: iconConfig, fallback: action.icon), action: action))
            case .translate:
                let action = TranslateAction(id: "translate")
                items.append(SectorItem(id: "translate", name: action.name, icon: resolveIcon(iconConfig: nil, fallback: action.icon), action: action))
            }
        }
        sectors = items
    }

    func executeSelected() async {
        guard let index = selectedIndex, index < sectors.count, let action = sectors[index].action else { return }
        await action.execute()
    }
}
