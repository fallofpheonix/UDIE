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
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingScale.sm) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(model.levelColor)
                            .frame(width: 8, height: 8)
                        Text(model.levelTitle)
                            .font(.system(size: 12, weight: .black))
                            .kerning(1.0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(model.levelColor.opacity(0.15))
                    .foregroundStyle(model.levelColor)
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.textSecondary.opacity(0.6))
                    }
                }
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.etaText)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                        Text("ESTIMATED TIME")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    
                    Rectangle()
                        .fill(ColorTokens.cardStroke.opacity(0.5))
                        .frame(width: 1, height: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.distanceText)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                        Text("DISTANCE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Label(model.primaryInstruction, systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(model.secondaryInstruction)
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(20)
            .glassStyle()
            .shadow(color: Color.black.opacity(0.15), radius: 20, y: 10)
        }
        .padding(SpacingScale.md)
        .background(ColorTokens.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous)
                .stroke(ColorTokens.cardStroke)
        )
        .shadow(
            color: isHovered ? Color.black.opacity(0.24) : ElevationTokens.shadowMedium,
            radius: isHovered ? ElevationTokens.cardShadowRadius + 4 : ElevationTokens.cardShadowRadius,
            y: isHovered ? 10 : 6
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
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
