import SwiftUI
import Combine

struct CityDashboardView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CityDashboardViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                ColorTokens.appBackground.ignoresSafeArea()
                
                ScrollView {
                    if viewModel.isLoading {
                        VStack(spacing: SpacingScale.lg) {
                            HStack(spacing: SpacingScale.md) {
                                SkeletonView().frame(height: 80)
                                SkeletonView().frame(height: 80)
                            }
                            .padding(.horizontal)
                            
                            SkeletonView().frame(height: 180)
                                .padding(.horizontal)
                            
                            VStack(spacing: SpacingScale.sm) {
                                ForEach(0..<3) { _ in
                                    SkeletonView().frame(height: 60)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    } else {
                        VStack(spacing: SpacingScale.lg) {
                            // Header Stats
                            HStack(spacing: SpacingScale.md) {
                            StatCard(
                                title: "City Risk Index",
                                value: String(format: "%.2f", viewModel.dashboardData?.heatmapSummary.avgRisk ?? 0),
                                trend: "+5%", // Static for now or derived from trend
                                color: viewModel.riskColor
                            )
                            
                            StatCard(
                                title: "Active Hotspots",
                                value: "\(viewModel.dashboardData?.topHotspots.count ?? 0)",
                                trend: "Stable",
                                color: ColorTokens.neutralAccent
                            )
                        }
                        .padding(.horizontal)
                        
                        // Risk Trend Chart (Simplified)
                        VStack(alignment: .leading, spacing: SpacingScale.sm) {
                            Text("24h Risk Evolution")
                                .font(.headline)
                                .foregroundStyle(ColorTokens.textPrimary)
                            
                            TrendChartView(data: viewModel.dashboardData?.cityRiskTrend ?? [])
                                .frame(height: 180)
                        }
                        .padding()
                        .background(ColorTokens.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous))
                        .padding(.horizontal)
                        
                        // Top Hotspots
                        VStack(alignment: .leading, spacing: SpacingScale.sm) {
                            Text("Top Risk Clusters")
                                .font(.headline)
                                .foregroundStyle(ColorTokens.textPrimary)
                            
                            if let hotspots = viewModel.dashboardData?.topHotspots, !hotspots.isEmpty {
                                ForEach(hotspots, id: \.rank) { hotspot in
                                    HotspotRow(hotspot: hotspot)
                                }
                            } else {
                                Text("No major hotspots detected")
                                    .font(.subheadline)
                                    .foregroundStyle(ColorTokens.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            }
                        }
                        .padding()
                        .background(ColorTokens.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous))
                        .padding(.horizontal)
                        
                        // Recent Incidents
                        VStack(alignment: .leading, spacing: SpacingScale.sm) {
                            Text("Recent Live Incidents")
                                .font(.headline)
                                .foregroundStyle(ColorTokens.textPrimary)
                            
                            if let incidents = viewModel.dashboardData?.recentIncidents, !incidents.isEmpty {
                                ForEach(incidents.prefix(5), id: \.observedAt) { incident in
                                    IncidentRow(incident: incident)
                                }
                            }
                        }
                        .padding()
                        .background(ColorTokens.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous))
                        .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("City Intelligence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .task {
                await viewModel.refresh()
            }
        }
    }
}

// MARK: - Subviews
struct StatCard: View {
    let title: String
    let value: String
    let trend: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingScale.xxs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(ColorTokens.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: SpacingScale.xs2) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(trend)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpacingScale.md)
        .background(ColorTokens.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous)
                .stroke(ColorTokens.cardStroke)
        )
    }
}

struct HotspotRow: View {
    let hotspot: HotspotDTO
    
    var body: some View {
        HStack {
            Circle()
                .fill(hotspot.peakRisk > 8 ? ColorTokens.highRisk : ColorTokens.mediumRisk)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading) {
                Text("Hotspot #\(hotspot.rank)")
                    .font(.subheadline.weight(.semibold))
                Text("\(hotspot.cellCount) adjacent cells")
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(String(format: "%.1f", hotspot.aggregatedRisk))
                    .font(.subheadline.monospaced().weight(.bold))
                Text("Aggregated Weight")
                    .font(.system(size: 8))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .padding(.vertical, SpacingScale.xxs)
    }
}

struct IncidentRow: View {
    let incident: RecentIncidentDTO
    
    var body: some View {
        HStack(spacing: SpacingScale.sm) {
            Circle()
                .fill(ColorTokens.mediumRisk.opacity(0.1))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(ColorTokens.mediumRisk)
                )
            
            VStack(alignment: .leading) {
                Text(incident.eventType.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.subheadline.weight(.medium))
                Text("Observed \(relativeTime(from: incident.observedAt))")
                    .font(.caption2)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            
            Spacer()
            
            Text(String(format: "%.1f", incident.severity))
                .font(.caption.monospaced().weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ColorTokens.highRisk.opacity(0.1))
                .foregroundStyle(ColorTokens.highRisk)
                .clipShape(Capsule())
        }
    }
    
    private func relativeTime(from isoString: String) -> String {
        // Simple relative time helper
        return "recently"
    }
}

struct TrendChartView: View {
    let data: [RiskTrendDTO]
    
    var body: some View {
        // Placeholder for a premium trend chart implementation
        GeometryReader { geo in
            Path { path in
                let points = data.map { $0.avgRisk }
                guard points.count > 1 else { return }
                
                let step = geo.size.width / CGFloat(points.count - 1)
                let maxVal = points.max() ?? 10
                let height = geo.size.height
                
                path.move(to: CGPoint(x: 0, y: height - (CGFloat(points[0] / maxVal) * height)))
                
                for i in 1..<points.count {
                    path.addLine(to: CGPoint(x: CGFloat(i) * step, y: height - (CGFloat(points[i] / maxVal) * height)))
                }
            }
            .stroke(ColorTokens.neutralAccent, lineWidth: 2)
            .background(
                LinearGradient(colors: [ColorTokens.neutralAccent.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom)
            )
        }
    }
}

// MARK: - ViewModel
@MainActor
class CityDashboardViewModel: ObservableObject {
    @Published var dashboardData: CityDashboardResponse?
    @Published var isLoading = false
    
    var riskColor: Color {
        let risk = dashboardData?.heatmapSummary.avgRisk ?? 0
        if risk > 7 { return ColorTokens.highRisk }
        if risk > 4 { return ColorTokens.mediumRisk }
        return ColorTokens.lowRisk
    }
    
    func refresh() async {
        isLoading = true
        do {
            // Using a default bounding box for the city (Delhi center approximation)
            dashboardData = try await APIClient.shared.fetchCityDashboard(
                minLat: 28.4,
                maxLat: 28.8,
                minLng: 77.0,
                maxLng: 77.4
            )
        } catch {
            print("Dashboard Refresh Failed: \(error)")
        }
        isLoading = false
    }
}
