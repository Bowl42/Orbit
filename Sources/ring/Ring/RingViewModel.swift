import AppKit
import Combine

class RingViewModel: ObservableObject {
    @Published var slots: [AppSlot] = []

    static let maxSlots = 8
    private let defaultsKey = "customSlots"

    /// Stored as array of bundle IDs; empty string means "no custom app for this slot"
    var customBundleIDs: [String?] {
        get {
            guard let raw = UserDefaults.standard.stringArray(forKey: defaultsKey) else {
                return Array(repeating: nil, count: Self.maxSlots)
            }
            return raw.map { $0.isEmpty ? nil : $0 }
        }
        set {
            UserDefaults.standard.set(newValue.map { $0 ?? "" }, forKey: defaultsKey)
        }
    }

    func refresh() {
        let customIDs = customBundleIDs
        let customSet = Set(customIDs.compactMap { $0 })

        // Build slots from custom config
        var result: [AppSlot] = customIDs.prefix(Self.maxSlots).map { bid in
            guard let bid else { return AppSlot.empty }
            var slot = AppSlot.custom(bundleID: bid)
            // Attach running instance if available
            slot.runningApp = runningApp(for: bid)
            return slot
        }

        // Pad to max
        while result.count < Self.maxSlots { result.append(AppSlot.empty) }

        // Running apps not already in custom slots
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { app in
                guard let bid = app.bundleIdentifier else { return false }
                return !customSet.contains(bid)
            }

        // Fill empty slots
        var ri = 0
        for i in result.indices where result[i].isEmpty {
            guard ri < running.count else { break }
            result[i] = AppSlot.running(running[ri])
            ri += 1
        }

        slots = result.filter { !$0.isEmpty }
    }

    func setCustomSlot(at index: Int, bundleID: String?) {
        var ids = customBundleIDs
        while ids.count <= index { ids.append(nil) }
        ids[index] = bundleID
        customBundleIDs = ids
    }

    func removeCustomSlot(at index: Int) {
        setCustomSlot(at: index, bundleID: nil)
    }

    private func runningApp(for bundleID: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleID }
    }
}
