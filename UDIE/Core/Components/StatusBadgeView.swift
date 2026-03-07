import SwiftUI

struct StatusBadgeView: View {
    let state: MapViewModel.BackendSyncState
    let eventCount: Int
    let lastUpdated: String

    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: SpacingScale.xs) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .rotationEffect(.degrees(state == .syncing ? rotation : 0))
                .animation(state == .syncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: rotation)
                .onAppear {
                    if state == .syncing { rotation = 360 }
                }
                .onChange(of: state) { _, newState in
                    if newState == .syncing {
                        rotation = 360
                    } else {
                        rotation = 0
                    }
                }

            Text(titleText)
                .font(.caption)
                .fontWeight(.semibold)

            if state != .connecting && state != .disconnected {
                Text("• \(eventCount) events")
                    .font(.caption2)
                    .foregroundStyle(ColorTokens.textSecondary)

                Text("• \(lastUpdated)")
                    .font(.caption2)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
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

    private var isError: Bool {
        if case .error = state { return true }
        return state == .disconnected
    }

    private var titleText: String {
        switch state {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .syncing:
            return "Syncing..."
        case .synced:
            return "Synced"
        case .error(let message):
            return "Sync Error: \(message.prefix(20))..."
        }
    }

    private var iconName: String {
        switch state {
        case .error, .disconnected:
            return "exclamationmark.triangle.fill"
        case .connecting, .syncing:
            return "arrow.trianglehead.2.clockwise"
        case .connected:
            return "dot.radiowaves.left.and.right"
        case .synced:
            return "checkmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch state {
        case .error, .disconnected:
            return ColorTokens.highRisk
        case .connecting, .syncing:
            return ColorTokens.mediumRisk
        case .connected, .synced:
            return ColorTokens.neutralAccent
        }
    }
}
