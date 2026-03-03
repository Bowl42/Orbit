import SwiftUI

struct AppPickerView: View {
    let apps: [InstalledApp]
    let onSelect: (InstalledApp) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    private var filtered: [InstalledApp] {
        guard !searchText.isEmpty else { return apps }
        let query = searchText.lowercased()
        return apps.filter {
            $0.name.lowercased().contains(query) || $0.bundleId.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose Application")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            TextField("Search apps...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            List(filtered) { app in
                Button {
                    onSelect(app)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(app.name)
                                .font(.body)
                            Text(app.bundleId)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
        .frame(width: 380, height: 440)
    }
}
