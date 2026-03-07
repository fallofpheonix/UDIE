import SwiftUI
import Combine

struct DisruptionInspectorView: View {
    let h3Index: String
    let coordinate: CoordinateDTO
    @StateObject private var viewModel = DisruptionInspectorViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingScale.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spatial Inspector")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(ColorTokens.textSecondary)
                    Text("Cell \(h3Index.prefix(10))...")
                        .font(.headline.monospaced())
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                Spacer()
                if let score = viewModel.insight?.riskScore {
                    RiskBadge(score: score)
                }
            }
            
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if let insight = viewModel.insight {
                VStack(alignment: .leading, spacing: SpacingScale.sm) {
                    MetricRow(label: "Dominant Pattern", value: insight.dominantEventType.replacingOccurrences(of: "_", with: " ").capitalized, icon: "brain.head.profile")
                    MetricRow(label: "Recent Events (24h)", value: "\(insight.recentEventCount)", icon: "exclamationmark.circle")
                    MetricRow(label: "Reliability Index", value: String(format: "%.2f", insight.reliabilityScore), icon: "shield.checkered")
                    MetricRow(label: "Forecast (30m)", value: String(format: "%.0f%% Prob.", insight.forecastProbability * 100), icon: "chart.line.uptrend.xyaxis")
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: SpacingScale.xs2) {
                    Text("Operational Context")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text("This cell is experiencing active risk based on clustered urban signals. The engine recommends avoiding stationary logistics in this sector due to historical pattern recurrence.")
                        .font(.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .lineSpacing(4)
                }
            }
        }
        .padding(SpacingScale.lg)
        .background(ColorTokens.surfacePrimary)
        .task {
            await viewModel.load(lat: coordinate.lat, lng: coordinate.lng)
        }
    }
}

struct RiskBadge: View {
    let score: Double
    
    var body: some View {
        Text(String(format: "%.1f", score))
            .font(.title3.monospaced().weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 1))
    }
    
    private var color: Color {
        if score > 7 { return ColorTokens.highRisk }
        if score > 4 { return ColorTokens.mediumRisk }
        return ColorTokens.lowRisk
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorTokens.textPrimary)
        }
    }
}

@MainActor
class DisruptionInspectorViewModel: ObservableObject {
    @Published var insight: CellInsightResponse?
    @Published var isLoading = false
    
    func load(lat: Double, lng: Double) async {
        isLoading = true
        do {
            insight = try await APIClient.shared.fetchCellInsight(lat: lat, lng: lng) 
        } catch {
            print("Insight load failed: \(error)")
        }
        isLoading = false
    }
}
