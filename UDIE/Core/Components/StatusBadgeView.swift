import SwiftUI

struct StatusBadgeView: View {
    let isError: Bool
    let eventCount: Int
    let lastUpdated: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "dot.radiowaves.left.and.right")
                .foregroundStyle(isError ? .red : .mint)
            
            Text(isError ? "Backend Warning" : "Backend Connected")
                .font(.caption)
                .fontWeight(.semibold)
            
            Text("• \(eventCount) events")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
            
            Text("• \(lastUpdated)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: isError
                    ? [Color.red.opacity(0.35), Color.black.opacity(0.3)]
                    : [Color.teal.opacity(0.32), Color.black.opacity(0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(radius: 4)
    }
}
