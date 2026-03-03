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

    struct SectorItem: Identifiable {
        let id: String
        let name: String
        let icon: NSImage?
        let action: (any OrbitAction)?
    }

    /// Calculate which sector the mouse is pointing at.
    /// `mouseLocation` is in screen coordinates.
    func updateSelection(mouseLocation: CGPoint) {
        let dx = mouseLocation.x - centerPoint.x
        let dy = mouseLocation.y - centerPoint.y
        let distance = sqrt(dx * dx + dy * dy)

        guard distance > deadZoneRadius else {
            selectedIndex = nil
            return
        }

        guard !sectors.isEmpty else {
            selectedIndex = nil
            return
        }

        // atan2 returns radians from -pi to pi, with 0 pointing right.
        var angle = atan2(dy, dx)

        // Convert to 0...2pi, with 0 pointing up (top), clockwise.
        // Subtract pi/2 to rotate so 0 = top.
        angle = -(angle - .pi / 2)

        // Normalize to 0...2pi.
        if angle < 0 { angle += 2 * .pi }

        let sectorAngle = (2 * .pi) / CGFloat(sectors.count)
        let index = Int(angle / sectorAngle) % sectors.count

        selectedIndex = index
    }

    /// Build sectors from config and recent apps.
    func buildSectors(config: OrbitConfig, recentApps: [RecentAppsTracker.AppInfo]) {
        var recentIndex = 0
        var items: [SectorItem] = []

        for sectorConfig in config.sectors.prefix(config.sectorCount) {
            switch sectorConfig {
            case .recent:
                if recentIndex < recentApps.count {
                    let app = recentApps[recentIndex]
                    let action = LaunchAppAction(
                        id: app.id,
                        name: app.name,
                        bundleIdentifier: app.id
                    )
                    items.append(SectorItem(
                        id: "recent-\(recentIndex)",
                        name: app.name,
                        icon: app.icon,
                        action: action
                    ))
                } else {
                    items.append(SectorItem(
                        id: "empty-\(recentIndex)",
                        name: "Empty",
                        icon: NSImage(
                            systemSymbolName: "circle.dashed",
                            accessibilityDescription: nil
                        ),
                        action: nil
                    ))
                }
                recentIndex += 1

            case .pinned(let bundleId, let name, _):
                let action = LaunchAppAction(
                    id: bundleId,
                    name: name,
                    bundleIdentifier: bundleId
                )
                items.append(SectorItem(
                    id: "pinned-\(bundleId)",
                    name: name,
                    icon: action.icon.nsImage,
                    action: action
                ))
            }
        }

        sectors = items
    }

    /// Execute the currently selected sector's action.
    func executeSelected() async {
        guard let index = selectedIndex, index < sectors.count,
              let action = sectors[index].action else { return }
        await action.execute()
    }
}
