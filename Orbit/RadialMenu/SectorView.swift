import SwiftUI

struct SectorView: View {
    let item: RadialMenuViewModel.SectorItem
    let isSelected: Bool
    let index: Int
    let count: Int
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let angle: Angle
    let radius: CGFloat

    var body: some View {
        ZStack {
            // Sector wedge highlight
            SectorShape(index: index, count: count, innerRadius: innerRadius, outerRadius: outerRadius)
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(0.18)
                        : Color.clear
                )

            // Icon
            iconContent
                .scaleEffect(isSelected ? 1.15 : 1.0)
                .shadow(color: .black.opacity(isSelected ? 0.5 : 0.2), radius: isSelected ? 6 : 3, y: isSelected ? 4 : 2)
                .offset(
                    x: cos(angle.radians) * radius,
                    y: -sin(angle.radians) * radius
                )
        }
        .zIndex(isSelected ? 1 : 0)
    }

    @ViewBuilder
    private var iconContent: some View {
        if let icon = item.icon {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 46, height: 46)
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
    }
}

// MARK: - Sector Shape
struct SectorShape: Shape {
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
