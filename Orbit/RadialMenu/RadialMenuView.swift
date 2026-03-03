import SwiftUI

struct RadialMenuView: View {
    let viewModel: RadialMenuViewModel

    @State private var isAppearing = false

    private let windowSize: CGFloat = 500
    private let outerRadius: CGFloat = 205
    private let innerRadius: CGFloat = 65
    private let centerRadius: CGFloat = 52
    private let iconRingRadius: CGFloat = 135

    var body: some View {
        ZStack {
            // Main Glass Background
            Circle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .frame(width: outerRadius * 2, height: outerRadius * 2)
                .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 15)
                .overlay(
                    Circle().stroke(.white.opacity(0.15), lineWidth: 0.5)
                )

            // Sector highlight wedges
            ForEach(Array(viewModel.sectors.enumerated()), id: \.element.id) { index, _ in
                SectorWedge(
                    index: index,
                    count: viewModel.sectors.count,
                    innerRadius: innerRadius,
                    outerRadius: outerRadius
                )
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            .white.opacity(viewModel.selectedIndex == index ? 0.2 : 0.0),
                            .white.opacity(viewModel.selectedIndex == index ? 0.05 : 0.0)
                        ]),
                        center: .center,
                        startRadius: innerRadius,
                        endRadius: outerRadius
                    )
                )
                .animation(.easeOut(duration: 0.2), value: viewModel.selectedIndex)
            }

            // Sector divider lines
            if viewModel.sectors.count > 1 {
                ForEach(0..<viewModel.sectors.count, id: \.self) { index in
                    let startAngle = sectorStartAngle(for: index)
                    SectorDivider(angle: startAngle, innerRadius: innerRadius, outerRadius: outerRadius)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, .white.opacity(0.15), .clear]),
                                startPoint: .center,
                                endPoint: UnitPoint(x: cos(startAngle.radians)*0.5 + 0.5, y: sin(startAngle.radians)*0.5 + 0.5)
                            ),
                            lineWidth: 0.5
                        )
                }
            }

            // Center label area
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .frame(width: centerRadius * 2, height: centerRadius * 2)
                    .overlay(
                        Circle().stroke(.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)

                VStack(spacing: 4) {
                    if let index = viewModel.selectedIndex, index < viewModel.sectors.count {
                        if let icon = viewModel.sectors[index].icon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 26, height: 26)
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                                .id("icon-\(viewModel.sectors[index].id)")
                        }
                        Text(viewModel.sectors[index].name)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 6)
                            .transition(.opacity)
                            .id("text-\(viewModel.sectors[index].id)")
                    } else {
                        Image(systemName: "circle.grid.cross")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(.white.opacity(0.5))
                            .transition(.opacity)
                    }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.selectedIndex)

            // Sector icons in a ring
            ForEach(Array(viewModel.sectors.enumerated()), id: \.element.id) { index, item in
                let angle = iconAngle(for: index)
                SectorView(
                    item: item,
                    isSelected: viewModel.selectedIndex == index,
                    index: index,
                    count: viewModel.sectors.count,
                    innerRadius: innerRadius,
                    outerRadius: outerRadius,
                    angle: angle,
                    radius: iconRingRadius
                )
                .opacity(isAppearing ? 1 : 0)
                .scaleEffect(isAppearing ? 1 : 0.4)
                .rotationEffect(isAppearing ? .zero : .degrees(20))
                .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(index) * 0.02), value: isAppearing)
            }
        }
        .frame(width: windowSize, height: windowSize)
        .scaleEffect(isAppearing ? 1 : 0.85)
        .opacity(isAppearing ? 1 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isAppearing)
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
        let cosVal = cos(angle.radians)
        let sinVal = sin(angle.radians)
        var path = Path()
        path.move(to: CGPoint(x: center.x + cosVal * innerRadius, y: center.y + sinVal * innerRadius))
        path.addLine(to: CGPoint(x: center.x + cosVal * outerRadius, y: center.y + sinVal * outerRadius))
        return path
    }
}
