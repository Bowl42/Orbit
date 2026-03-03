import SwiftUI

struct RadialMenuView: View {
    let viewModel: RadialMenuViewModel

    @State private var isAppearing = false

    private let diameter: CGFloat = 320
    private let iconRingRadius: CGFloat = 110
    private let centerRadius: CGFloat = 40

    var body: some View {
        ZStack {
            // Center label
            VStack(spacing: 2) {
                if let index = viewModel.selectedIndex, index < viewModel.sectors.count {
                    Text(viewModel.sectors[index].name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .transition(.opacity)
                        .id(viewModel.sectors[index].id)
                } else {
                    Text("Orbit")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: centerRadius * 2, height: centerRadius * 2)
            .animation(.easeInOut(duration: 0.15), value: viewModel.selectedIndex)

            // Sector icons in a ring
            ForEach(Array(viewModel.sectors.enumerated()), id: \.element.id) { index, item in
                let sectorAngle = sectorAngle(for: index)
                SectorView(
                    item: item,
                    isSelected: viewModel.selectedIndex == index,
                    angle: sectorAngle,
                    radius: iconRingRadius
                )
                .opacity(isAppearing ? 1 : 0)
                .scaleEffect(isAppearing ? 1 : 0.3)
                .animation(.spring(duration: 0.3, bounce: 0.25).delay(Double(index) * 0.02), value: isAppearing)
            }
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(isAppearing ? 1 : 0.8)
        .opacity(isAppearing ? 1 : 0)
        .animation(.spring(duration: 0.25, bounce: 0.2), value: isAppearing)
        .onAppear { isAppearing = true }
    }

    /// Calculate the angle for a sector, starting from top (12 o'clock), going clockwise.
    private func sectorAngle(for index: Int) -> Angle {
        let count = viewModel.sectors.count
        guard count > 0 else { return .zero }
        let step = 360.0 / Double(count)
        return .degrees(90 - step * Double(index))
    }
}
