import SwiftUI

struct SectorView: View {
    let item: RadialMenuViewModel.SectorItem
    let isSelected: Bool
    let angle: Angle
    let radius: CGFloat
    let delay: Double

    @State private var animateIn = false

    var body: some View {
        ZStack {
            // 仅仅保留图标本体，移除所有外部方框和底座
            VStack {
                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.primary.opacity(0.6))
                }
            }
            // 选中时的动态效果：放大并增加发光阴影
            .scaleEffect(isSelected ? 1.3 : 1.0)
            .shadow(
                color: isSelected ? Color.accentColor.opacity(0.5) : Color.black.opacity(0.15),
                radius: isSelected ? 15 : 4,
                y: isSelected ? 0 : 2
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .offset(
            x: cos(angle.radians) * radius,
            y: -sin(angle.radians) * radius
        )
        // 弹出入场动画
        .scaleEffect(animateIn ? 1.0 : 0.4)
        .opacity(animateIn ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(delay)) {
                animateIn = true
            }
        }
    }
}
