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
            // Static layers (never re-rendered on selection change)
            staticBackground

            // Selection-dependent layers
            sectorHighlights
            centerInfo
            sectorIcons
        }
        .frame(width: windowSize, height: windowSize)
        .scaleEffect(isAppearing ? 1 : 0.85)
        .opacity(isAppearing ? 1 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isAppearing)
        .onAppear { isAppearing = true }
    }

    // MARK: - Static background (drawn once, never redrawn)

    private var staticBackground: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: outerRadius * 2, height: outerRadius * 2)
                .overlay(
                    Circle().stroke(.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)

            if viewModel.sectors.count > 1 {
                ForEach(0..<viewModel.sectors.count, id: \.self) { index in
                    let startAngle = sectorStartAngle(for: index)
                    SectorDivider(angle: startAngle, innerRadius: innerRadius, outerRadius: outerRadius)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
            }
        }
        .drawingGroup()
    }

    // MARK: - Sector highlights (lightweight fill changes)

    private var sectorHighlights: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            guard let selected = viewModel.selectedIndex, !viewModel.sectors.isEmpty else { return }

            let count = viewModel.sectors.count
            let step = 360.0 / Double(count)
            let start = Angle.degrees(-90 + step * Double(selected) - step / 2)
            let end = Angle.degrees(-90 + step * Double(selected) + step / 2)

            var path = Path()
            path.addArc(center: center, radius: outerRadius, startAngle: start, endAngle: end, clockwise: false)
            path.addArc(center: center, radius: innerRadius, startAngle: end, endAngle: start, clockwise: true)
            path.closeSubpath()

            context.fill(path, with: .color(.accentColor.opacity(0.25)))
        }
        .allowsHitTesting(false)
    }

    // MARK: - Center info

    private var centerInfo: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: centerRadius * 2, height: centerRadius * 2)
                .overlay(
                    Circle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )

            VStack(spacing: 4) {
                if let index = viewModel.selectedIndex, index < viewModel.sectors.count {
                    if let icon = viewModel.sectors[index].icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 26, height: 26)
                            .id("icon-\(viewModel.sectors[index].id)")
                    }
                    Text(viewModel.sectors[index].name)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 6)
                        .id("text-\(viewModel.sectors[index].id)")
                } else {
                    Image(systemName: "circle.grid.cross")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Sector icons

    private var sectorIcons: some View {
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

    // MARK: - Geometry helpers

    private func iconAngle(for index: Int) -> Angle {
        let count = viewModel.sectors.count
        guard count > 0 else { return .zero }
        let step = 360.0 / Double(count)
        return .degrees(90 - step * Double(index))
    }

    private func sectorStartAngle(for index: Int) -> Angle {
        let count = viewModel.sectors.count
        let step = 360.0 / Double(count)
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
