import SwiftUI

struct SkeletonView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(ColorTokens.surfacePrimary)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, ColorTokens.textPrimary.opacity(0.05), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: -geo.size.width * 0.5 + (geo.size.width * 1.5 * phase))
                }
            )
            .mask(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonView()
                .frame(width: 120, height: 16)
            SkeletonView()
                .frame(height: 24)
            SkeletonView()
                .frame(width: 200, height: 14)
        }
        .padding()
        .background(ColorTokens.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ColorTokens.cardStroke))
    }
}
