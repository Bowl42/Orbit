import AppKit

struct LaunchAppAction: OrbitAction {
    let id: String
    let name: String
    let bundleIdentifier: String
    var subtitle: String? { nil }

    var icon: ActionIcon {
        .appIcon(bundleId: bundleIdentifier)
    }

    func execute() async {
        // Try activating first if already running
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        )
        if let app = running.first {
            await MainActor.run {
                _ = app.activate()
            }
            return
        }

        // Otherwise launch
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else {
            print("App not found: \(bundleIdentifier)")
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        do {
            try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
        } catch {
            print("Failed to launch \(bundleIdentifier): \(error)")
        }
    }
}
