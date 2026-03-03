import SwiftUI

struct SectorView: View {
    let item: RadialMenuViewModel.SectorItem
    let isSelected: Bool
    let angle: Angle
    let radius: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "questionmark.app")
                    .font(.system(size: 28))
                    .frame(width: 40, height: 40)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(
                    color: .black.opacity(isSelected ? 0.4 : 0.2),
                    radius: isSelected ? 8 : 4,
                    y: isSelected ? 4 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    .white.opacity(isSelected ? 0.8 : 0.1),
                    lineWidth: isSelected ? 2 : 0.5
                )
        )
        .scaleEffect(isSelected ? 1.15 : 0.9)
        .opacity(isSelected ? 1.0 : 0.6)
        .brightness(isSelected ? 0.1 : 0)
        .offset(
            x: cos(angle.radians) * radius,
            y: -sin(angle.radians) * radius
        )
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
    }
}
