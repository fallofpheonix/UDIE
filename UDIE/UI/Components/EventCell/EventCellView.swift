import SwiftUI

struct EventCellView: View {
    let model: EventListCardViewData
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingScale.xs2) {
            HStack {
                Text(model.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Text(model.severityLabel)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .padding(.horizontal, SpacingScale.xs)
                    .padding(.vertical, SpacingScale.xxs)
                    .background(ColorTokens.chipBackground)
                    .clipShape(Capsule())
            }

            HStack(spacing: SpacingScale.xs) {
                Circle()
                    .fill(model.tint)
                    .frame(width: 8, height: 8)
                Text(model.distanceText)
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            HStack {
                Text(model.confidenceText)
                Text("•")
                Text(model.coordinateText)
            }
            .font(.caption2)
            .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(SpacingScale.md)
        .background(model.background)
        .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous)
                .stroke(ColorTokens.cardStroke)
        )
        .shadow(
            color: isHovered ? Color.black.opacity(0.24) : ElevationTokens.shadowSoft,
            radius: isHovered ? 12 : 8,
            y: isHovered ? 8 : 4
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
