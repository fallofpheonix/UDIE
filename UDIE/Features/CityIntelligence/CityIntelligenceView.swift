import SwiftUI
import Combine

struct CityIntelligenceView: View {
    @StateObject private var viewModel = IntelligenceViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                ColorTokens.adaptiveBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Emerging Risks (Rule: signals before details)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Emerging Risk Clusters")
                                .font(Typography.heading)
                            
                            ForEach(viewModel.clusters) { cluster in
                                ClusterHighlightCard(cluster: cluster)
                            }
                        }
                        
                        // 2. Anomaly Alerts
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pattern Anomalies")
                                .font(Typography.heading)
                            
                            ForEach(viewModel.anomalies) { anomaly in
                                AnomalyCard(anomaly: anomaly)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Intelligence")
        }
    }
}

struct ClusterHighlightCard: View {
    let cluster: RiskCluster
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(cluster.severityColor.opacity(0.1)).frame(width: 50, height: 50)
                Image(systemName: cluster.icon).foregroundStyle(cluster.severityColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(cluster.location)
                    .font(Typography.body.bold())
                Text(cluster.description)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(Int(cluster.confidence * 100))%")
                    .font(Typography.body.bold())
                    .foregroundStyle(ColorTokens.accent)
                Text("Confidence")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .padding()
        .background(ColorTokens.adaptiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(ColorTokens.cardStroke))
    }
}

struct AnomalyCard: View {
    let anomaly: AnomalyPoint
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusBadge(text: "ANOMALY", color: ColorTokens.mediumRisk)
                Spacer()
                Text(anomaly.time)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            
            Text(anomaly.title)
                .font(Typography.body.bold())
            
            Text(anomaly.details)
                .font(Typography.bodySmall)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding()
        .background(ColorTokens.adaptiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Models

struct RiskCluster: Identifiable {
    let id = UUID()
    let location: String
    let description: String
    let icon: String
    let severityColor: Color
    let confidence: Double
}

struct AnomalyPoint: Identifiable {
    let id = UUID()
    let title: String
    let details: String
    let time: String
}

@MainActor
final class IntelligenceViewModel: ObservableObject {
    @Published var clusters: [RiskCluster] = [
        RiskCluster(location: "South Delhi Cluster", description: "Rising trend in water-logging signals near Ring Road.", icon: "cloud.rain.fill", severityColor: ColorTokens.mediumRisk, confidence: 0.88),
        RiskCluster(location: "Central Hub Spike", description: "Sudden accumulation of traffic incidents (n=12) in 15min.", icon: "car.2.fill", severityColor: ColorTokens.highRisk, confidence: 0.94)
    ]
    
    @Published var anomalies: [AnomalyPoint] = [
        AnomalyPoint(title: "Deviating Risk Gradient", details: "Risk index in Sector 4 is 40% higher than historical Sunday baseline.", time: "10m ago"),
        AnomalyPoint(title: "Signal Dropout Detect", details: "Losing connectivity from 4 sensors in North Zone. Stability unverifiable.", time: "22m ago")
    ]
}
