import SwiftUI

struct StatusBadgeView: View {
    let isError: Bool
    let eventCount: Int
    let lastUpdated: String

    var body: some View {
        HStack(spacing: SpacingScale.xs) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "dot.radiowaves.left.and.right")
                .foregroundStyle(isError ? ColorTokens.highRisk : ColorTokens.neutralAccent)

            Text(isError ? "Backend Warning" : "Backend Connected")
                .font(.caption)
                .fontWeight(.semibold)

            Text("• \(eventCount) events")
                .font(.caption2)
                .foregroundStyle(ColorTokens.textSecondary)

            Text("• \(lastUpdated)")
                .font(.caption2)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .foregroundStyle(ColorTokens.textPrimary)
        .padding(.horizontal, SpacingScale.sm)
        .padding(.vertical, SpacingScale.xs)
        .background(isError ? ColorTokens.surfaceTintedC : ColorTokens.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.pillRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ElevationTokens.pillRadius, style: .continuous)
                .stroke(ColorTokens.cardStroke, lineWidth: 1)
        )
        .shadow(color: ElevationTokens.shadowSoft, radius: 5, y: 2)
    }
}
