import AppKit

struct AppSlot: Identifiable {
    let id = UUID()

    /// Live running app (auto-filled)
    var runningApp: NSRunningApplication?

    /// Bundle ID for user-configured custom slots
    var customBundleID: String?

    var isEmpty: Bool { runningApp == nil && customBundleID == nil }
    var isCustom: Bool { customBundleID != nil }

    var displayName: String {
        if let app = runningApp { return app.localizedName ?? "App" }
        if let bid = customBundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            return url.deletingPathExtension().lastPathComponent
        }
        return ""
    }

    var icon: NSImage? {
        if let app = runningApp { return app.icon }
        if let bid = customBundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }

    func activate() {
        if let app = runningApp, !app.isTerminated {
            app.activate(options: [.activateIgnoringOtherApps])
            return
        }
        // Not running (or terminated since last refresh) — launch it
        let url = runningApp?.bundleURL
            ?? customBundleID.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
        if let url { NSWorkspace.shared.open(url) }
    }

    static var empty: AppSlot { AppSlot() }

    static func custom(bundleID: String) -> AppSlot {
        var s = AppSlot(); s.customBundleID = bundleID; return s
    }

    static func running(_ app: NSRunningApplication) -> AppSlot {
        var s = AppSlot(); s.runningApp = app; return s
    }
}
