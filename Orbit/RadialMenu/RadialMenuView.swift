import SwiftUI

struct RadialMenuView: View {
    let viewModel: RadialMenuViewModel
    @State private var isAppearing = false

    private let size: CGFloat = 340
    private let iconRadius: CGFloat = 112
    private let innerRadius: CGFloat = 58
    private let timer = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Level 0: Glass rim highlight (blur handled by Panel's NSVisualEffectView)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.1), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(width: size - 1, height: size - 1)

            // Level 1: Selection Wedge
            Canvas { context, sz in
                guard let selectedIndex = viewModel.selectedIndex else { return }
                let count = viewModel.sectors.count
                guard count > 0 else { return }

                let step = 360.0 / Double(count)
                let startAngle = Angle.degrees(-90 + step * Double(selectedIndex) - step / 2 + 0.5)
                let endAngle = Angle.degrees(-90 + step * Double(selectedIndex) + step / 2 - 0.5)

                let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
                var path = Path()
                path.addArc(center: center, radius: sz.width / 2, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
                path.closeSubpath()

                    context.fill(path, with: .color(Color.white.opacity(0.15)))
                
                var rim = Path()
                rim.addArc(center: center, radius: sz.width / 2 - 1, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                context.stroke(rim, with: .color(Color.white.opacity(0.6)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .animation(.spring(response: 0.15, dampingFraction: 0.8), value: viewModel.selectedIndex)

            // Level 2: Icons
            ForEach(Array(viewModel.sectors.enumerated()), id: \.element.id) { index, item in
                SectorView(
                    item: item,
                    isSelected: viewModel.selectedIndex == index,
                    angle: iconAngle(for: index),
                    radius: iconRadius,
                    delay: Double(index) * 0.02
                )
            }

            // Level 3: Center Hub
            ZStack {
                if let item = selectedItem {
                    VStack(spacing: 4) {
                        if let icon = item.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(color: .white.opacity(0.3), radius: 12)
                                .transition(.scale(0.8).combined(with: .opacity))
                        }
                        Text(item.name)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 4)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                } else {
                    // Default Floating Logo
                    Image(systemName: "circle.grid.cross.fill")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.white.opacity(0.6))
                        .shadow(color: .white.opacity(0.3), radius: 10)
                }
            }
            .scaleEffect(isAppearing ? 1 : 0.85)
        }
        .frame(width: size, height: size)
        .opacity(isAppearing ? 1 : 0)
        .onAppear { isAppearing = true }
        .onReceive(timer) { _ in
            viewModel.updateSelection(mouseLocation: NSEvent.mouseLocation)
        }
    }

    private var selectedItem: RadialMenuViewModel.SectorItem? {
        if let index = viewModel.selectedIndex, index < viewModel.sectors.count {
            return viewModel.sectors[index]
        }
        return nil
    }

    private func iconAngle(for index: Int) -> Angle {
        let step = 360.0 / Double(max(1, viewModel.sectors.count))
        return Angle.degrees(90 - step * Double(index))
    }
}
