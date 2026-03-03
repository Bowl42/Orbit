import AppKit
import Combine

@MainActor
@Observable
final class RecentAppsTracker {
    var recentApps: [AppInfo] = []
    let maxRecent: Int

    private var cancellable: AnyCancellable?
    private let selfBundleID = Bundle.main.bundleIdentifier

    struct AppInfo: Identifiable, Equatable, Hashable, @unchecked Sendable {
        let id: String  // bundleIdentifier
        let name: String
        let icon: NSImage

        static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    init(maxRecent: Int = 20) {
        self.maxRecent = maxRecent

        cancellable = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { notification -> NSRunningApplication? in
                notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] app in
                MainActor.assumeIsolated {
                    self?.handleAppActivation(app)
                }
            }

        seedWithRunningApps()
    }

    private func handleAppActivation(_ app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier,
              bundleID != selfBundleID,
              bundleID != "com.apple.finder",
              app.activationPolicy == .regular
        else { return }

        let name = app.localizedName ?? bundleID
        let icon = app.icon ?? NSWorkspace.shared.icon(forFile: "/Applications")

        let info = AppInfo(id: bundleID, name: name, icon: icon)

        recentApps.removeAll { $0.id == bundleID }
        recentApps.insert(info, at: 0)

        if recentApps.count > maxRecent {
            recentApps = Array(recentApps.prefix(maxRecent))
        }
    }

    func seedWithRunningApps() {
        let running = NSWorkspace.shared.runningApplications
            .filter {
                $0.activationPolicy == .regular
                    && $0.bundleIdentifier != selfBundleID
                    && $0.bundleIdentifier != "com.apple.finder"
            }

        for app in running {
            guard let bundleID = app.bundleIdentifier else { continue }
            if recentApps.contains(where: { $0.id == bundleID }) { continue }

            let name = app.localizedName ?? bundleID
            let icon = app.icon ?? NSWorkspace.shared.icon(forFile: "/Applications")
            recentApps.append(AppInfo(id: bundleID, name: name, icon: icon))
        }
    }

    func topRecent(_ count: Int) -> [AppInfo] {
        Array(recentApps.prefix(count))
    }
}
