import SwiftUI

// MARK: - Shared Visual Effect View
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        // Keep it lucid and responsive to background
        v.appearance = NSAppearance(named: .vibrantLight)
        return v
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Prismatic Tahoe Liquid Engine (Zero-Fog Edition)
struct LiquidBackground: View {
    @State private var t: CGFloat = 0.0
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        let points: [SIMD2<Float>] = [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [Float(0.5 + sin(t) * 0.1), Float(0.5 + cos(t * 0.8) * 0.1)], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1]
        ]
        
        // Use high-saturation, low-opacity spectral colors to "tint" the refraction
        let colors: [Color] = [
            .blue.opacity(0.3), .purple.opacity(0.2), .indigo.opacity(0.3),
            .cyan.opacity(0.15), .clear, .orange.opacity(0.15),
            .pink.opacity(0.2), .blue.opacity(0.15), .purple.opacity(0.3)
        ]
        
        return MeshGradient(width: 3, height: 3, points: points, colors: colors)
            .onReceive(timer) { _ in t += 0.02 }
            .blur(radius: 15)
    }
}

// MARK: - Lucid Sequoia Glass (The "Soap Bubble" Physics)
struct SequoiaGlass<Content: View>: View {
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
                    // 1. THE LUCID BASE - Selection material is the most transparent & vibrant
                    VisualEffectView(material: .selection, blendingMode: .behindWindow)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    
                    // 2. OPTICAL ENHANCEMENT - Boosting background vibrancy without fogging
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.clear)
                        .saturation(2.2) // CRITICAL: This gives the "Glass" look over colors
                        .brightness(0.02)
                    
                    // 3. PRISMATIC REFRACTION - The liquid flow inside
                    LiquidBackground()
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .opacity(0.4)
                    
                    // 4. SPECULAR OPTICAL EDGE - Physics-based rim highlight
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .white.opacity(0.1), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                    
                    // 5. INTERNAL SURFACE REFLECTION
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1.5)
                        .blur(radius: 1)
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 25, x: 0, y: 15)
    }
}
