import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.adaptiveBackground.ignoresSafeArea()
                
                // Background Depth Elements
                VStack {
                    Circle()
                        .fill(ColorTokens.accent.opacity(0.15))
                        .blur(radius: 80)
                        .offset(x: -100, y: -100)
                    Spacer()
                    Circle()
                        .fill(ColorTokens.mediumRisk.opacity(0.1))
                        .blur(radius: 80)
                        .offset(x: 100, y: 100)
                }
                
                ScrollView {
                    VStack(spacing: 28) {
                        // 1. COMMAND HEADER: Situational Awareness
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Text("SITUATIONAL AWARENESS")
                                    .font(.system(size: 12, weight: .black))
                                    .kerning(1.2)
                                    .foregroundStyle(ColorTokens.textSecondary)
                                Spacer()
                                StatusBadge(text: "LIVE", color: .green)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DELHI CORE")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(ColorTokens.accent)
                                
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text("MEDIUM")
                                        .font(.system(size: 42, weight: .black, design: .rounded))
                                        .foregroundStyle(ColorTokens.mediumRisk)
                                    Text("RISK")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(ColorTokens.textSecondary)
                                }
                            }
                            
                            HStack(spacing: 24) {
                                MiniMetric(label: "Active Nodes", value: "1,242", color: ColorTokens.textPrimary)
                                MiniMetric(label: "Risk Index", value: "0.42", color: ColorTokens.mediumRisk)
                                MiniMetric(label: "Stability", value: "98.4%", color: .green)
                            }
                        }
                        .padding(24)
                        .glassStyle()
                        .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
                        
                        // 2. SIGNALS: Intelligence Feed Highlight
                        HomeIntelligenceSection()
                            .padding(.top, 8)
                        
                        // 3. ACTION: Decision Shortcuts
                        QuickActionsGrid()
                    }
                    .padding(20)
                }
                .refreshable {
                    await viewModel.refreshData()
                }
            }
            .navigationTitle("Command Center")
            .onAppear {
                Task { await viewModel.refreshData() }
            }
        }
    }
}

// MARK: - Components

struct HomeIntelligenceSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("INTELLIGENCE BREADCRUMBS")
                    .font(Typography.captionBold)
                    .foregroundStyle(ColorTokens.textSecondary)
                Spacer()
                NavigationLink("Fly to Map", destination: MapOperationsView())
                    .font(Typography.captionBold)
                    .foregroundStyle(ColorTokens.accent)
            }
            
            VStack(spacing: 8) {
                SignalHighlightRow(title: "Flooding Spike", location: "Sector 4", intensity: "HIGH", color: ColorTokens.highRisk)
                SignalHighlightRow(title: "Congestion Drift", location: "Ring Road", intensity: "MED", color: ColorTokens.mediumRisk)
            }
        }
    }
}

struct SignalHighlightRow: View {
    let title: String
    let location: String
    let intensity: String
    let color: Color
    
    var body: some View {
        HStack {
            Capsule().fill(color).frame(width: 4, height: 20)
            VStack(alignment: .leading) {
                Text(title).font(Typography.bodySmall.bold())
                Text(location).font(Typography.caption).foregroundStyle(ColorTokens.textSecondary)
            }
            Spacer()
            Text(intensity)
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.1))
                .foregroundStyle(color)
                .clipShape(Capsule())
        }
        .padding(16)
        .glassStyle(cornerRadius: 12, opacity: 0.1)
    }
}

struct QuickActionsGrid: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("QUICK DECISIONS")
                .font(.system(size: 11, weight: .black))
                .kerning(1.2)
                .foregroundStyle(ColorTokens.textSecondary)
            
            HStack(spacing: 16) {
                QuickActionItem(title: "Evaluate Route", icon: "arrow.triangle.swap", color: ColorTokens.accent)
                QuickActionItem(title: "Risk Analysis", icon: "chart.bar.fill", color: ColorTokens.mediumRisk)
            }
        }
    }
}

struct QuickActionItem: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(color)
            }
            
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassStyle(cornerRadius: 16, opacity: 0.1)
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
    }
}



struct MiniMetric: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }
}
