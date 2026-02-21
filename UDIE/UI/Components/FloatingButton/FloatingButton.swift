import SwiftUI

struct FloatingButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ColorTokens.neutralPrimary)
                .frame(width: 50, height: 50)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.buttonRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ElevationTokens.buttonRadius, style: .continuous)
                        .stroke(ColorTokens.cardStroke)
                )
                .shadow(color: ElevationTokens.cardShadow, radius: ElevationTokens.cardShadowRadius, y: 6)
        }
        .buttonStyle(.plain)
    }
}
