import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var viewModel: RingViewModel
    @State private var installedApps: [InstalledApp] = []
    @State private var searchText = ""
    @State private var selectedSlot: Int? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            leftPanel
                .frame(width: 320)
            Divider()
            rightPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 800, height: 520)
        .onAppear { loadApps() }
    }

    // MARK: - Left panel

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ring Slots")
                .font(.headline)
                .padding(.bottom, 6)

            Text(hintText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 34, alignment: .topLeading)
                .padding(.bottom, 20)

            ringCanvas
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer()

            if let i = selectedSlot,
               i < viewModel.customBundleIDs.count,
               viewModel.customBundleIDs[i] != nil {
                Button("Clear slot \(i + 1)") {
                    viewModel.removeCustomSlot(at: i)
                    selectedSlot = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            }
        }
        .padding(20)
    }

    private var hintText: String {
        guard let i = selectedSlot else {
            return "Tap a slot to select, or drag an app directly onto a slot."
        }
        let ids = viewModel.customBundleIDs
        if i < ids.count, ids[i] != nil {
            return "Slot \(i + 1) selected — tap or drag an app to replace it."
        }
        return "Slot \(i + 1) selected — tap an app to assign it."
    }

    private var ringCanvas: some View {
        let r: CGFloat = 100
        let canvasSize: CGFloat = 260

        return ZStack {
            Circle()
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                .background(Circle().fill(Color.primary.opacity(0.025)))
                .frame(width: canvasSize - 20, height: canvasSize - 20)

            ForEach(0..<RingViewModel.maxSlots, id: \.self) { i in
                let angle = (2 * .pi / CGFloat(RingViewModel.maxSlots)) * CGFloat(i) - (.pi / 2)
                let bid: String? = i < viewModel.customBundleIDs.count
                    ? viewModel.customBundleIDs[i] : nil

                SettingsSlotCell(
                    index: i,
                    bundleID: bid,
                    isSelected: selectedSlot == i,
                    onTap: {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                            selectedSlot = selectedSlot == i ? nil : i
                        }
                    },
                    onClear: {
                        viewModel.removeCustomSlot(at: i)
                        if selectedSlot == i { selectedSlot = nil }
                    },
                    onDrop: { bid in
                        viewModel.setCustomSlot(at: i, bundleID: bid)
                        selectedSlot = nil
                    }
                )
                .offset(x: cos(angle) * r, y: sin(angle) * r)
            }
        }
        .frame(width: canvasSize, height: canvasSize)
    }

    // MARK: - Right panel

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Applications")
                .font(.headline)
                .padding(.bottom, 10)

            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.bottom, 12)

            appIconGrid
        }
        .padding(20)
    }

    private var appIconGrid: some View {
        let filtered = searchText.isEmpty ? installedApps
            : installedApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        let assignedIDs = Set(viewModel.customBundleIDs.compactMap { $0 })

        return ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 56, maximum: 68), spacing: 8)],
                spacing: 8
            ) {
                ForEach(filtered) { app in
                    AppIconCell(
                        app: app,
                        isAssigned: assignedIDs.contains(app.bundleID),
                        slotSelected: selectedSlot != nil
                    ) {
                        guard let slot = selectedSlot else { return }
                        viewModel.setCustomSlot(at: slot, bundleID: app.bundleID)
                        let ids = viewModel.customBundleIDs
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                            selectedSlot = ((slot + 1)..<RingViewModel.maxSlots).first {
                                $0 >= ids.count || ids[$0] == nil
                            }
                        }
                    }
                }
            }
            .padding(8)
        }
        .scrollIndicators(.hidden)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Data

    private func loadApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let dirs = ["/Applications", "/System/Applications", "/System/Applications/Utilities"]
            let apps: [InstalledApp] = dirs
                .flatMap { dir -> [URL] in
                    (try? FileManager.default.contentsOfDirectory(
                        at: URL(fileURLWithPath: dir),
                        includingPropertiesForKeys: nil
                    )) ?? []
                }
                .compactMap { url -> InstalledApp? in
                    guard url.pathExtension == "app",
                          let bid = Bundle(url: url)?.bundleIdentifier else { return nil }
                    return InstalledApp(
                        name: url.deletingPathExtension().lastPathComponent,
                        bundleID: bid,
                        icon: NSWorkspace.shared.icon(forFile: url.path)
                    )
                }
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

            DispatchQueue.main.async { installedApps = apps }
        }
    }
}

// MARK: - Slot cell

struct SettingsSlotCell: View {
    let index: Int
    let bundleID: String?
    let isSelected: Bool
    let onTap: () -> Void
    let onClear: () -> Void
    let onDrop: (String) -> Void

    @State private var isHovered = false
    @State private var isTargeted = false

    private let size: CGFloat = 52

    private var icon: NSImage? {
        guard let bid = bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(background)
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(border, lineWidth: (isSelected || isTargeted) ? 2 : 1)

            if isTargeted {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
            } else if let img = icon {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .opacity(isHovered ? 0.55 : 1)
            } else {
                Text("\(index + 1)")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isTargeted ? 1.07 : 1)
        // X badge on hover when assigned
        .overlay(alignment: .topTrailing) {
            if isHovered && !isTargeted && bundleID != nil {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.75))
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .offset(x: 8, y: -8)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        // Extra hit area
        .frame(width: size + 16, height: size + 16)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHovered = h } }
        .onTapGesture(perform: onTap)
        .onDrop(of: [UTType.plainText], isTargeted: $isTargeted) { providers in
            providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                guard let bid = item as? String, !bid.isEmpty else { return }
                DispatchQueue.main.async { onDrop(bid) }
            }
            return true
        }
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isSelected)
        .help(bundleID != nil ? "Slot \(index + 1)" : "Slot \(index + 1) — empty")
    }

    private var background: Color {
        if isTargeted { return Color.accentColor.opacity(0.12) }
        if isSelected { return Color.accentColor.opacity(0.10) }
        if isHovered  { return Color.primary.opacity(0.08) }
        return Color.primary.opacity(0.04)
    }

    private var border: Color {
        if isTargeted || isSelected { return Color.accentColor }
        return Color.primary.opacity(0.12)
    }
}

// MARK: - App icon cell

struct AppIconCell: View {
    let app: InstalledApp
    let isAssigned: Bool
    let slotSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isHovered && slotSelected
                        ? Color.accentColor.opacity(0.14)
                        : (isHovered ? Color.primary.opacity(0.07) : Color.clear)
                )
                .frame(width: 64, height: 64)

            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 11))

            if isAssigned {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
                    .font(.system(size: 14))
                    .offset(x: 4, y: 4)
            }
        }
        .frame(width: 64, height: 64)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHovered = h } }
        .onTapGesture(perform: onTap)
        .onDrag { NSItemProvider(object: app.bundleID as NSString) }
        .help(app.name)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Model

struct InstalledApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String
    let icon: NSImage
}
