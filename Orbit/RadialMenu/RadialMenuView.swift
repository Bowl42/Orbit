import SwiftUI

struct RadialMenuView: View {
    let viewModel: RadialMenuViewModel
    @State private var isAppearing = false
    
    // UI Constants
    private let size: CGFloat = 340
    private let iconRadius: CGFloat = 112
    private let innerRadius: CGFloat = 58
    
    // ULTIMATE TRACKING: Use a timer inside the view to poll mouse location.
    // This ensures high-frequency updates and bypasses all window focus issues.
    private let timer = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // 1. High-Contrast Selection Wedge
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

                // Pure VisionOS white highlight
                context.fill(path, with: .color(Color.white.opacity(0.2)))
                
                var rim = Path()
                rim.addArc(center: center, radius: sz.width / 2 - 1, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                context.stroke(rim, with: .color(Color.white.opacity(0.5)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .animation(.spring(response: 0.15, dampingFraction: 0.8), value: viewModel.selectedIndex)

            // 3. Icons
            ForEach(Array(viewModel.sectors.enumerated()), id: \.element.id) { index, item in
                SectorView(
                    item: item,
                    isSelected: viewModel.selectedIndex == index,
                    angle: iconAngle(for: index),
                    radius: iconRadius,
                    delay: Double(index) * 0.02
                )
            }

            // 4. Center Hub
            LiquidGlassView(cornerRadius: innerRadius) {
                ZStack {
                    if let item = selectedItem {
                        VStack(spacing: 4) {
                            if let icon = item.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .transition(.scale(0.8).combined(with: .opacity))
                            }
                            Text(item.name)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    } else {
                        Image(systemName: "circle.grid.cross.fill")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .frame(width: innerRadius * 2, height: innerRadius * 2)
            }
            .scaleEffect(isAppearing ? 1 : 0.8)
        }
        .frame(width: size, height: size)
        .opacity(isAppearing ? 1 : 0)
        .onAppear { isAppearing = true }
        .onReceive(timer) { _ in
            // Actively update selection based on global mouse location
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
