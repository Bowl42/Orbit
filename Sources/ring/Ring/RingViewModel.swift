import AppKit
import Combine

class RingViewModel: ObservableObject {
    @Published var slots: [AppSlot] = []
    @Published var customBundleIDs: [String?]

    static let maxSlots = 8
    private let defaultsKey = "customSlots"

    init() {
        if let raw = UserDefaults.standard.stringArray(forKey: "customSlots") {
            customBundleIDs = raw.map { $0.isEmpty ? nil : $0 }
        } else {
            customBundleIDs = Array(repeating: nil, count: Self.maxSlots)
        }
    }

    func refresh() {
        let customIDs = customBundleIDs
        let customSet = Set(customIDs.compactMap { $0 })

        var result: [AppSlot] = customIDs.prefix(Self.maxSlots).map { bid in
            guard let bid else { return AppSlot.empty }
            var slot = AppSlot.custom(bundleID: bid)
            slot.runningApp = runningApp(for: bid)
            return slot
        }

        while result.count < Self.maxSlots { result.append(AppSlot.empty) }

        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { app in
                guard let bid = app.bundleIdentifier else { return false }
                return !customSet.contains(bid)
            }

        var ri = 0
        for i in result.indices where result[i].isEmpty {
            guard ri < running.count else { break }
            result[i] = AppSlot.running(running[ri])
            ri += 1
        }

        slots = result.filter { !$0.isEmpty }
    }

    func setCustomSlot(at index: Int, bundleID: String?) {
        while customBundleIDs.count <= index { customBundleIDs.append(nil) }
        customBundleIDs[index] = bundleID
        persist()
    }

    func removeCustomSlot(at index: Int) {
        setCustomSlot(at: index, bundleID: nil)
    }

    private func persist() {
        UserDefaults.standard.set(customBundleIDs.map { $0 ?? "" }, forKey: defaultsKey)
    }

    private func runningApp(for bundleID: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleID }
    }
}
