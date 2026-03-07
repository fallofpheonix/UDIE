import SwiftUI

struct StatusBadge: View {
    let text: String
    let color: Color
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 4) {
            if text == "LIVE" {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0.3 : 1.0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    }
            }
            
            Text(text)
                .font(.system(size: 10, weight: .black))
                .kerning(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
    }
}
