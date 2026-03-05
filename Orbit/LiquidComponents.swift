import SwiftUI

struct LiquidBackground: View {
    @State private var t: CGFloat = 0.0
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        // High-Luminosity Spatial Colors (Vision Pro Style)
        let points: [SIMD2<Float>] = [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [Float(0.5 + sin(t) * 0.1), Float(0.5 + cos(t * 0.8) * 0.1)], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1]
        ]
        
        let colors: [Color] = [
            .indigo.opacity(0.2), .blue.opacity(0.15), .purple.opacity(0.2),
            .cyan.opacity(0.1), .white.opacity(0.1), .blue.opacity(0.15),
            .purple.opacity(0.15), .indigo.opacity(0.1), .blue.opacity(0.2)
        ]
        
        return MeshGradient(width: 3, height: 3, points: points, colors: colors)
            .onReceive(timer) { _ in
                t += 0.02
            }
    }
}

// MARK: - Liquid Glass Container
struct LiquidGlassView<Content: View>: View {
    var cornerRadius: CGFloat = 24
    var content: Content
    
    init(cornerRadius: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .background {
                ZStack {
                    // 1. Crystal Clear System Material
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    // 2. Extra luminosity layer
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                    
                    // 3. Specular High-Light Edge (Simulating refraction)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .white.opacity(0.1), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                    
                    // 4. Volume shadow (Inner)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 2)
                        .blur(radius: 2)
                        .offset(x: 0, y: 2)
                        .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 20)
    }
}
