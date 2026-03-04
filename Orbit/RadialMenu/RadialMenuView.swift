import SwiftUI

struct RadialMenuView: View {
    let viewModel: RadialMenuViewModel
    @State private var isAppearing = false

    private let size: CGFloat = 340
    private let iconRadius: CGFloat = 114
    private let innerRadius: CGFloat = 58

    var body: some View {
        ZStack {
            // 1. 高亮层
            selectionHighlightLayer

            // 2. 装饰层
            backgroundDecorLayer

            // 3. 图标层
            iconLayer

            // 4. 中心枢纽
            CenterHub(
                selectedItem: viewModel.selectedIndex != nil ? viewModel.sectors[viewModel.selectedIndex!] : nil,
                radius: innerRadius
            )
            .scaleEffect(isAppearing ? 1 : 0.85)
        }
        .frame(width: size, height: size)
        .opacity(isAppearing ? 1 : 0)
        .onAppear { isAppearing = true }
        .onChange(of: viewModel.selectedIndex) { old, new in
            if old != new, new != nil {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            }
        }
    }

    // MARK: - Subviews

    private var selectionHighlightLayer: some View {
        Canvas { context, sz in
            guard let selectedIndex = viewModel.selectedIndex else { return }
            let count = viewModel.sectors.count
            guard count > 0 else { return }

            let step = 360.0 / Double(count)
            let startAngle = Angle.degrees(-90 + step * Double(selectedIndex) - step / 2 + 0.5)
            let endAngle = Angle.degrees(-90 + step * Double(selectedIndex) + step / 2 - 0.5)

            let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
            var path = Path()
            path.addArc(center: center, radius: sz.width / 2 - 2, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            path.addArc(center: center, radius: innerRadius + 2, startAngle: endAngle, endAngle: startAngle, clockwise: true)
            path.closeSubpath()

            // Tahoe 风格：乳白色微透高光
            context.fill(path, with: .color(Color.primary.opacity(0.08)))
            
            var rim = Path()
            rim.addArc(center: center, radius: sz.width / 2 - 3, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            context.stroke(rim, with: .color(Color.primary.opacity(0.12)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: viewModel.selectedIndex)
    }

    private var backgroundDecorLayer: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.02), lineWidth: 1)
                .frame(width: size, height: size)
            
            if viewModel.sectors.count > 1 {
                ForEach(0..<viewModel.sectors.count, id: \.self) { i in
                    DividerDot(index: i, count: viewModel.sectors.count, radius: size / 2 - 4)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 2, height: 2)
                }
            }
        }
        .drawingGroup()
    }

    private var iconLayer: some View {
        ForEach(Array(viewModel.sectors.enumerated()), id: \.element.id) { index, item in
            SectorView(
                item: item,
                isSelected: viewModel.selectedIndex == index,
                angle: iconAngle(for: index),
                radius: iconRadius,
                delay: Double(index) * 0.03
            )
        }
    }

    private func iconAngle(for index: Int) -> Angle {
        let step = 360.0 / Double(max(1, viewModel.sectors.count))
        return Angle.degrees(90 - step * Double(index))
    }
}

// 分隔装饰点
struct DividerDot: Shape {
    let index: Int
    let count: Int
    let radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let step = 360.0 / Double(count)
        let angle = Angle.degrees(-90 + step * Double(index) - step / 2).radians
        let x = center.x + cos(angle) * radius
        let y = center.y + sin(angle) * radius
        
        var path = Path()
        path.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
        return path
    }
}

// MARK: - 中心枢纽 (Tahoe Glass Lens)
struct CenterHub: View {
    let selectedItem: RadialMenuViewModel.SectorItem?
    let radius: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: radius * 2, height: radius * 2)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(colors: [.primary.opacity(0.15), .primary.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: .black.opacity(0.12), radius: 12, y: 8)

            VStack(spacing: 3) {
                if let item = selectedItem {
                    if let icon = item.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .transition(.scale(0.8).combined(with: .opacity))
                    }
                    Text(item.name)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .frame(width: radius * 1.6)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Image(systemName: "circle.grid.cross.fill")
                        .font(.system(size: 24, weight: .ultraLight))
                        .foregroundStyle(.primary.opacity(0.2))
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: selectedItem?.id)
        }
    }
}
