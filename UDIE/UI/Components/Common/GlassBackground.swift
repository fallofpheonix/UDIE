import SwiftUI

struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 16
    var blurRadius: CGFloat = 10
    var opacity: Double = 0.2
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    BlurView(style: .systemThinMaterial)
                    
                    ColorTokens.surfacePrimary
                        .opacity(opacity)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.1),
                                Color.black.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

extension View {
    func glassStyle(cornerRadius: CGFloat = 16, blurRadius: CGFloat = 10, opacity: Double = 0.2) -> some View {
        self.modifier(GlassBackground(cornerRadius: cornerRadius, blurRadius: blurRadius, opacity: opacity))
    }
}
