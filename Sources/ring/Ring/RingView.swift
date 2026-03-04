import SwiftUI
import AppKit

struct RingView: View {
    @ObservedObject var viewModel: RingViewModel
    let onDismiss: () -> Void
    let onActivate: (AppSlot) -> Void

    @State private var hoveredID: UUID?
    @State private var appeared = false

    private let radius: CGFloat = 95
    private let iconSize: CGFloat = 48

    var body: some View {
        ZStack {
            // Full-view tap-to-dismiss area
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            // Glass background — Orbit-style dark ultraThinMaterial circle
            Circle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .frame(width: 260, height: 260)
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
                .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 0.5))
                .onTapGesture { onDismiss() }

            // App icons
            ForEach(Array(viewModel.slots.enumerated()), id: \.element.id) { index, slot in
                let angle = slotAngle(index: index, total: viewModel.slots.count)
                AppIconView(slot: slot, isHovered: hoveredID == slot.id, size: iconSize)
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.65)
                            .delay(Double(index) * 0.02),
                        value: appeared
                    )
                    .onHover { hoveredID = $0 ? slot.id : nil }
                    .onTapGesture {
                        onActivate(slot)
                    }
            }
        }
        .frame(width: 280, height: 280)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }

    private func slotAngle(index: Int, total: Int) -> CGFloat {
        guard total > 0 else { return 0 }
        // Start at top (-π/2), go clockwise
        return (2 * .pi / CGFloat(total)) * CGFloat(index) - .pi / 2
    }
}

struct AppIconView: View {
    let slot: AppSlot
    let isHovered: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(isHovered ? Color(red: 0.1, green: 0.7, blue: 1.0).opacity(0.25) : Color.clear)
                .blur(radius: isHovered ? 8 : 0)
                .frame(width: size + 16, height: size + 16)

            if let icon = slot.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
            } else {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size, height: size)
            }
        }
        .scaleEffect(isHovered ? 1.18 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
        .help(slot.displayName)
    }
}
