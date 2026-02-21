import SwiftUI

struct RouteRiskViewData {
    let levelTitle: String
    let levelColor: Color
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
                VStack(alignment: .leading, spacing: SpacingScale.xxs) {
                    Text("Route Risk")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(model.levelTitle)
                        .font(.headline)
                        .foregroundStyle(model.levelColor)
                }

                Spacer()

                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Label(model.delayEstimate, systemImage: "clock")
                Spacer()
                Label("\(model.eventCount)", systemImage: "exclamationmark.triangle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(model.recommendation)
                .font(.caption)
                .foregroundStyle(.primary)
        }
        .padding(SpacingScale.md)
        .background(ColorTokens.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous)
                .stroke(ColorTokens.cardStroke)
        )
        .shadow(color: ElevationTokens.cardShadow, radius: ElevationTokens.cardShadowRadius, y: 6)
    }
}
