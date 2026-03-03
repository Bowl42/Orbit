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

    // Modern color scheme for highlights
    private let glowColor = Color(red: 0.1, green: 0.7, blue: 1.0)

    var body: some View {
        ZStack {
            // Sector Border Highlight
            SectorShape(index: index, count: count, innerRadius: innerRadius, outerRadius: outerRadius)
                .stroke(
                    isSelected ? AnyShapeStyle(selectionGradient) : AnyShapeStyle(Color.clear),
                    lineWidth: isSelected ? 1.5 : 0
                )

            // The application icon
            ZStack {
                // Background glow circle when selected
                if isSelected {
                    Circle()
                        .fill(glowColor.opacity(0.25))
                        .frame(width: 64, height: 64)
                        .blur(radius: 12)
                        .transition(.scale.combined(with: .opacity))
                }
                
                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 46, height: 46)
                        .shadow(color: .black.opacity(isSelected ? 0.6 : 0.25), radius: isSelected ? 8 : 4, x: 0, y: isSelected ? 6 : 2)
                        .scaleEffect(isSelected ? 1.15 : 1.0)
                } else {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                        .frame(width: 46, height: 46)
                        .scaleEffect(isSelected ? 1.15 : 1.0)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }
            }
            .offset(
                x: cos(angle.radians) * radius,
                y: -sin(angle.radians) * radius
            )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
        .zIndex(isSelected ? 1 : 0) // Bring selected sector to front to prevent border overlap issues
    }

    /// A vibrant angular gradient for the selected state border.
    private var selectionGradient: AngularGradient {
        let step = 360.0 / Double(count)
        let start = Angle.degrees(-90 + step * Double(index) - step / 2)
        return AngularGradient(
            gradient: Gradient(colors: [
                glowColor.opacity(0.0),
                glowColor.opacity(0.8),
                glowColor,
                glowColor.opacity(0.8),
                glowColor.opacity(0.0)
            ]),
            center: .center,
            startAngle: start - .degrees(15),
            endAngle: start + .degrees(step) + .degrees(15)
        )
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
