import SwiftUI
import Combine
import Charts

struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                ColorTokens.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        if viewModel.isLoading {
                            ForEach(0..<3) { _ in
                                SkeletonChartCard()
                            }
                        } else {
                            // 1. Disruption Frequency Trend
                            ChartContainer(title: "Disruption Frequency Trend") {
                                Chart(viewModel.frequencyData) { item in
                                    LineMark(
                                        x: .value("Time", item.time),
                                        y: .value("Count", item.count)
                                    )
                                    .foregroundStyle(ColorTokens.accent)
                                    .interpolationMethod(.catmullRom)
                                    
                                    AreaMark(
                                        x: .value("Time", item.time),
                                        y: .value("Count", item.count)
                                    )
                                    .foregroundStyle(ColorTokens.accent.opacity(0.1))
                                }
                            }
                            
                            // 2. Hotspot Growth
                            ChartContainer(title: "Hotspot Growth Rate") {
                                Chart(viewModel.growthData) { item in
                                    BarMark(
                                        x: .value("Day", item.day),
                                        y: .value("Growth", item.value)
                                    )
                                    .foregroundStyle(item.value > 0.5 ? ColorTokens.highRisk : ColorTokens.accent)
                                    .cornerRadius(4)
                                }
                            }
                            
                            // 3. Risk Distribution
                            ChartContainer(title: "Risk Level Distribution") {
                                Chart(viewModel.distributionData) { item in
                                    SectorMark(
                                        angle: .value("Value", item.value),
                                        innerRadius: .ratio(0.6),
                                        angularInset: 2
                                    )
                                    .foregroundStyle(item.color)
                                    .annotation(position: .overlay) {
                                        Text("\(Int(item.value))%")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Analytics")
            .task {
                await viewModel.loadData()
            }
        }
    }
}

struct ChartContainer<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
                .frame(height: 200)
        }
        .padding()
        .background(ColorTokens.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ColorTokens.cardStroke))
    }
}

struct SkeletonChartCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(ColorTokens.surfaceSecondary)
                .frame(width: 150, height: 20)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTokens.surfaceSecondary)
                .frame(height: 180)
        }
        .padding()
        .background(ColorTokens.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Models

struct FrequencyPoint: Identifiable {
    let id = UUID()
    let time: String
    let count: Int
}

struct GrowthPoint: Identifiable {
    let id = UUID()
    let day: String
    let value: Double
}

struct DistributionPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var frequencyData: [FrequencyPoint] = []
    @Published var growthData: [GrowthPoint] = []
    @Published var distributionData: [DistributionPoint] = []
    
    func loadData() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        frequencyData = [
            FrequencyPoint(time: "08:00", count: 12),
            FrequencyPoint(time: "10:00", count: 45),
            FrequencyPoint(time: "12:00", count: 32),
            FrequencyPoint(time: "14:00", count: 68),
            FrequencyPoint(time: "16:00", count: 85),
            FrequencyPoint(time: "18:00", count: 54)
        ]
        growthData = [
            GrowthPoint(day: "Mon", value: 0.35),
            GrowthPoint(day: "Tue", value: 0.41),
            GrowthPoint(day: "Wed", value: 0.56),
            GrowthPoint(day: "Thu", value: 0.48),
            GrowthPoint(day: "Fri", value: 0.62),
            GrowthPoint(day: "Sat", value: 0.44),
            GrowthPoint(day: "Sun", value: 0.38)
        ]
        distributionData = [
            DistributionPoint(label: "Low", value: 44, color: ColorTokens.lowRisk),
            DistributionPoint(label: "Medium", value: 36, color: ColorTokens.mediumRisk),
            DistributionPoint(label: "High", value: 20, color: ColorTokens.highRisk)
        ]
        isLoading = false
    }
}
