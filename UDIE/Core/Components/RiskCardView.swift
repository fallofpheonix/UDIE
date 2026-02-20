import SwiftUI

struct RiskCardView: View {
    let risk: RouteRisk
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Route Risk")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                    Text(risk.level.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                    .foregroundColor(.white)

                Spacer()

                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(Int((risk.score * 100).rounded()))%")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("Model Score")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.75))
                }
                ProgressView(value: risk.score)
                    .tint(.white)
            }

            HStack {
                Label(String(format: "%.1f km", risk.distanceKM), systemImage: "arrow.triangle.pull")
                Spacer()
                Label(String(format: "%.0f min", risk.durationMinutes), systemImage: "clock.fill")
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.9))
        }
        .padding(14)
        .background(
            ZStack {
                risk.level.color
                Color.black.opacity(0.08)
            }
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(0.28),
            radius: 10,
            x: 0,
            y: 8
        )
    }
}
