import SwiftUI

struct EventCellView: View {
    let event: GeoEvent

    private var severityProgress: Double {
        min(max(Double(event.severity) / 5.0, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingScale.xs) {
            HStack {
                Text(event.eventType.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text("S\(event.severity)")
                    .font(.caption2)
                    .fontWeight(.bold)
            }

            ProgressView(value: severityProgress)
                .tint(event.eventType.displayColor)

            HStack {
                Text("Conf: \(Int((event.confidence * 100).rounded()))%")
                Spacer()
                Text(String(format: "%.4f, %.4f", event.latitude, event.longitude))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(SpacingScale.sm)
        .background(ColorTokens.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous)
                .stroke(ColorTokens.cardStroke)
        )
    }
}
