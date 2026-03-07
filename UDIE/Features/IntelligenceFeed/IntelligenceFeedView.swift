import SwiftUI
import Combine

struct IntelligenceFeedView: View {
    @StateObject private var viewModel = IntelligenceFeedViewModel()
    
    var body: some View {
        ZStack {
            ColorTokens.appBackground.ignoresSafeArea()
            
            VStack {
                if viewModel.isLoading {
                    ProgressView("Syncing signals...")
                        .padding()
                }
                
                List(viewModel.feedItems) { item in
                    FeedCard(item: item)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Intelligence Feed")
        .onAppear {
            Task { await viewModel.loadFeed() }
        }
    }
}

struct FeedCard: View {
    let item: FeedItemData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.title)
                    .font(.headline)
                Spacer()
                Text(item.timestamp)
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            
            Text(item.description)
                .font(.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)
            
            HStack {
                StatusBadge(text: item.severityLabel, color: item.severityColor)
                Spacer()
                Text("H3: \(item.h3Index.prefix(10))...")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .padding()
        .background(ColorTokens.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ColorTokens.cardStroke))
    }
}

// MARK: - Models & Component Placeholders

struct FeedItemData: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let timestamp: String
    let severityLabel: String
    let severityColor: Color
    let h3Index: String
}



@MainActor
final class IntelligenceFeedViewModel: ObservableObject {
    @Published var feedItems: [FeedItemData] = []
    @Published var isLoading = false
    
    func loadFeed() async {
        isLoading = true
        // Mocking for Phase 3 shell
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        feedItems = [
            FeedItemData(title: "Accident Cluster", description: "Multiple signals detected near AIIMS Flyover. Traffic flow degraded.", timestamp: "2m ago", severityLabel: "High", severityColor: ColorTokens.highRisk, h3Index: "893c2a4d5ffffff"),
            FeedItemData(title: "Construction Alert", description: "New construction activity detected near Ring Road. Lane closures expected.", timestamp: "5m ago", severityLabel: "Medium", severityColor: ColorTokens.mediumRisk, h3Index: "893c2a4d2ffffff"),
            FeedItemData(title: "Water Logging", description: "Sensor reports indicate water accumulation near ITO underpass.", timestamp: "12m ago", severityLabel: "High", severityColor: ColorTokens.highRisk, h3Index: "893c2a4d1ffffff")
        ]
        isLoading = false
    }
}
