import SwiftUI

struct RadialMenuView: View {
    let viewModel: RadialMenuViewModel

    @State private var isAppearing = false

    private let diameter: CGFloat = 420
    private let iconRingRadius: CGFloat = 145
    private let centerRadius: CGFloat = 45
    private let innerRadius: CGFloat = 50
    private let outerRadius: CGFloat = 210  // diameter / 2

    var body: some View {
        ZStack {
            // Sector highlight wedges
            ForEach(Array(viewModel.sectors.enumerated()), id: \.element.id) { index, _ in
                SectorWedge(
                    index: index,
                    count: viewModel.sectors.count,
                    innerRadius: innerRadius,
                    outerRadius: outerRadius
                )
                .fill(.white.opacity(viewModel.selectedIndex == index ? 0.15 : 0))
                .animation(.easeOut(duration: 0.15), value: viewModel.selectedIndex)
            }

            // Sector divider lines
            if viewModel.sectors.count > 1 {
                ForEach(0..<viewModel.sectors.count, id: \.self) { index in
                    let startAngle = sectorStartAngle(for: index)
                    SectorDivider(angle: startAngle, innerRadius: innerRadius, outerRadius: outerRadius)
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                }
            }

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
                let angle = iconAngle(for: index)
                SectorView(
                    item: item,
                    isSelected: viewModel.selectedIndex == index,
                    angle: angle,
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

    /// Angle for positioning icons — center of each sector, from top clockwise.
    private func iconAngle(for index: Int) -> Angle {
        let count = viewModel.sectors.count
        guard count > 0 else { return .zero }
        let step = 360.0 / Double(count)
        return .degrees(90 - step * Double(index))
    }

    /// Start angle of a sector edge (for divider lines).
    private func sectorStartAngle(for index: Int) -> Angle {
        let count = viewModel.sectors.count
        let step = 360.0 / Double(count)
        // Offset by half a sector so dividers sit between icons
        return .degrees(-90 + step * Double(index) - step / 2)
    }
}

// MARK: - Sector wedge shape

struct SectorWedge: Shape {
    let index: Int
    let count: Int
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let step = 360.0 / Double(count)
        // Start from top (-90°), offset by half sector so wedge centers on icon
        let start = Angle.degrees(-90 + step * Double(index) - step / 2)
        let end = Angle.degrees(-90 + step * Double(index) + step / 2)

        var path = Path()
        path.addArc(center: center, radius: outerRadius, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}

// MARK: - Sector divider line

struct SectorDivider: Shape {
    let angle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let cos = cos(angle.radians)
        let sin = sin(angle.radians)
        var path = Path()
        path.move(to: CGPoint(x: center.x + cos * innerRadius, y: center.y + sin * innerRadius))
        path.addLine(to: CGPoint(x: center.x + cos * outerRadius, y: center.y + sin * outerRadius))
        return path
    }
}
