import SwiftUI

struct RouteRiskViewData {
    let levelTitle: String
    let levelColor: Color
    let etaText: String
    let distanceText: String
    let arrivalText: String
    let primaryInstruction: String
    let secondaryInstruction: String
    let delayEstimate: String
    let eventCount: Int
    let recommendation: String
}

struct RiskSummaryCard: View {
    let model: RouteRiskViewData
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingScale.sm) {
            HStack {
                statLabel(model.etaText, icon: "clock")
                Spacer(minLength: SpacingScale.xs)
                statLabel(model.distanceText, icon: "point.topleft.down.curvedto.point.bottomright.up")
                Spacer(minLength: SpacingScale.xs)
                statLabel(model.arrivalText, icon: "calendar")
                Spacer()
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .padding(SpacingScale.xs)
                        .background(ColorTokens.chipBackground)
                        .clipShape(Capsule())
                }
                .buttonStyle(PressScaleButtonStyle())
            }

            VStack(alignment: .leading, spacing: SpacingScale.xxs) {
                Text(model.levelTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(model.levelColor)
                Text(model.primaryInstruction)
                    .font(.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text(model.secondaryInstruction)
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Divider()

            HStack {
                Label("\(model.eventCount) events", systemImage: "exclamationmark.triangle")
                Spacer()
                Label(model.delayEstimate, systemImage: "clock.arrow.circlepath")
            }
            .font(.caption)
            .foregroundStyle(ColorTokens.textSecondary)

            Text(model.recommendation)
                .font(.caption)
                .foregroundStyle(ColorTokens.textPrimary)
        }
        .padding(SpacingScale.md)
        .background(ColorTokens.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous)
                .stroke(ColorTokens.cardStroke)
        )
        .shadow(color: ElevationTokens.shadowMedium, radius: ElevationTokens.cardShadowRadius, y: 6)
    }

    private func statLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: SpacingScale.xxs) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(ColorTokens.textSecondary)
    }
}
