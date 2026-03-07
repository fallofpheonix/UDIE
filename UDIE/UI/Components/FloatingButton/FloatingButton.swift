import SwiftUI

struct FloatingButton: View {
    let systemName: String
    let action: () -> Void
    let size: CGFloat

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ColorTokens.textPrimary)
                .frame(width: size, height: size)
                .background(ColorTokens.controlFill)
                .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.floatingControlRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ElevationTokens.floatingControlRadius, style: .continuous)
                        .stroke(ColorTokens.cardStroke)
                )
                .shadow(color: ElevationTokens.shadowMedium, radius: 8, y: 4)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

extension FloatingButton {
    init(systemName: String, size: CGFloat = 50, action: @escaping () -> Void) {
        self.systemName = systemName
        self.action = action
        self.size = size
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.12, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
