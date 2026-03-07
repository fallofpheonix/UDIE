import SwiftUI

struct TimelineSlider: View {
    @Binding var value: Double // 0 to 100, where 100 is LIVE
    let onEditingChanged: (Bool) -> Void
    
    private var isLive: Bool {
        value >= 98
    }
    
    private var timeLabel: String {
        if isLive {
            return "LIVE"
        } else {
            let hoursBack = Int((100 - value) * 0.12)
            return "-\(hoursBack)h"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingScale.xxs) {
            HStack {
                Text("Temporal Playback")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ColorTokens.textSecondary)
                Spacer()
                Text(timeLabel)
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(isLive ? ColorTokens.lowRisk : ColorTokens.mediumRisk)
                    .padding(.horizontal, SpacingScale.xs)
                    .padding(.vertical, 2)
                    .background((isLive ? ColorTokens.lowRisk : ColorTokens.mediumRisk).opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Slider(value: $value, in: 0...100, onEditingChanged: onEditingChanged)
                .accentColor(isLive ? ColorTokens.neutralAccent : Color(hex: "FC913A"))
            
            HStack {
                Text("-12h")
                Spacer()
                Text("-6h")
                Spacer()
                Text("Now")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(SpacingScale.md)
        .background(ColorTokens.surfacePrimary.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous)
                .stroke(ColorTokens.cardStroke)
        )
        .shadow(color: ElevationTokens.shadowMedium, radius: 8, y: 4)
    }
}
