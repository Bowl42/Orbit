import SwiftUI

struct QuickActionsView: View {
    let onDismiss: () -> Void

    @State private var hoveredID: UUID?
    @State private var appeared = false

    private let actions = QuickAction.all

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                actionRow(action)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 6)
                    .animation(
                        .spring(response: 0.25, dampingFraction: 0.7).delay(Double(index) * 0.04),
                        value: appeared
                    )

                if index < actions.count - 1 {
                    Divider().padding(.horizontal, 10)
                }
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .frame(width: 180)
        .onAppear { appeared = true }
    }

    private func actionRow(_ action: QuickAction) -> some View {
        HStack(spacing: 10) {
            Image(systemName: action.icon)
                .font(.system(size: 14))
                .frame(width: 20)
            Text(action.title)
                .font(.system(size: 13))
            Spacer()
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(hoveredID == action.id ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .onHover { hoveredID = $0 ? action.id : nil }
        .onTapGesture {
            onDismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action.perform()
            }
        }
    }
}
