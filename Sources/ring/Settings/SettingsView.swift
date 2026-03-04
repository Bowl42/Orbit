import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var viewModel: RingViewModel
    @State private var installedApps: [InstalledApp] = []
    @State private var searchText = ""

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left — slot grid
            VStack(alignment: .leading, spacing: 12) {
                Text("Ring Slots")
                    .font(.headline)
                    .padding(.bottom, 2)
                slotGrid
                Text("Drag apps from the right onto a slot. Tap a slot to clear it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding()
            .frame(width: 230)

            Divider()

            // Right — app list
            VStack(alignment: .leading, spacing: 6) {
                Text("Applications")
                    .font(.headline)
                    .padding(.bottom, 2)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                appList
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .frame(width: 480, height: 380)
        .onAppear { loadApps() }
    }

    // MARK: - Slot grid

    private var slotGrid: some View {
        let ids = viewModel.customBundleIDs
        return LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(40), spacing: 6), count: 5),
            spacing: 6
        ) {
            ForEach(0..<RingViewModel.maxSlots, id: \.self) { i in
                slotCell(index: i, bundleID: i < ids.count ? ids[i] : nil)
            }
        }
    }

    private func slotCell(index: Int, bundleID: String?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.06))
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                )

            if let bid = bundleID,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text("\(index + 1)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
            providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                if let bid = item as? String, !bid.isEmpty {
                    DispatchQueue.main.async { viewModel.setCustomSlot(at: index, bundleID: bid) }
                }
            }
            return true
        }
        .onTapGesture { viewModel.removeCustomSlot(at: index) }
        .help(bundleID != nil ? "Click to clear" : "Drop an app here")
    }

    // MARK: - App list

    private var appList: some View {
        let filtered = searchText.isEmpty ? installedApps
            : installedApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filtered) { app in
                    appRow(app)
                }
            }
        }
    }

    private func appRow(_ app: InstalledApp) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            Text(app.name)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onDrag {
            NSItemProvider(object: app.bundleID as NSString)
        }
    }

    // MARK: - Load apps

    private func loadApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let dirs = ["/Applications", "/System/Applications",
                        "/System/Applications/Utilities"]
            let urls = dirs.flatMap { dir -> [URL] in
                let url = URL(fileURLWithPath: dir)
                return (try? FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: nil)) ?? []
            }
            let apps: [InstalledApp] = urls.compactMap { url in
                guard url.pathExtension == "app",
                      let bid = Bundle(url: url)?.bundleIdentifier else { return nil }
                let name = url.deletingPathExtension().lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                return InstalledApp(name: name, bundleID: bid, icon: icon)
            }.sorted { $0.name < $1.name }

            DispatchQueue.main.async { installedApps = apps }
        }
    }
}

struct InstalledApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String
    let icon: NSImage
}
