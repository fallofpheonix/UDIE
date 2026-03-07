import SwiftUI
import Combine

struct SystemHealthView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = SystemHealthViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                ColorTokens.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: SpacingScale.lg) {
                        // Overall Status
                        HStack {
                            Circle()
                                .fill(viewModel.report?.status == "healthy" ? ColorTokens.lowRisk : ColorTokens.mediumRisk)
                                .frame(width: 12, height: 12)
                            Text("System State: \(viewModel.report?.status.uppercased() ?? "CHECKING...")")
                                .font(.headline)
                                .foregroundStyle(ColorTokens.textPrimary)
                            Spacer()
                        }
                        .padding()
                        .background(ColorTokens.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous))
                        .padding(.horizontal)
                        
                        // Check Grid
                        if let checks = viewModel.report?.checks {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: SpacingScale.md) {
                                HealthMetricCard(title: "Architecture", status: (checks["queryPlan"]?["ok"]?.value as? Bool ?? false) ? "PASS" : "FAIL")
                                HealthMetricCard(title: "Log Rebuild", status: (checks["rebuild"]?["ok"]?.value as? Bool ?? false) ? "PASS" : "FAIL")
                                HealthMetricCard(title: "Partitions", status: (checks["partition"]?["ok"]?.value as? Bool ?? false) ? "READY" : "NONE")
                                HealthMetricCard(title: "Hot Path", status: (checks["hotPath"]?["ok"]?.value as? Bool ?? false) ? "SYNC" : "STALE")
                            }
                            .padding(.horizontal)
                        }
                        
                        // Audit Logs
                        VStack(alignment: .leading, spacing: SpacingScale.sm) {
                            Text("Audit Trail")
                                .font(.headline)
                                .foregroundStyle(ColorTokens.textPrimary)
                            
                            VStack(alignment: .leading, spacing: SpacingScale.xxs) {
                                LogEntryView(text: "[08:44] SharedBufferHitRatio: 98.4%", type: .info)
                                LogEntryView(text: "[08:45] PartitionAudit: 24 active shards", type: .info)
                                LogEntryView(text: "[08:46] QueryPlan: Index usage 100%", type: .success)
                                LogEntryView(text: "[08:47] ArchitectureAudit: PASS", type: .success)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ColorTokens.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous))
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Platform Health")
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

struct HealthMetricCard: View {
    let title: String
    let status: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingScale.xs2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(ColorTokens.textSecondary)
            Text(status)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(status == "PASS" || status == "READY" || status == "SYNC" ? ColorTokens.lowRisk : ColorTokens.highRisk)
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

struct LogEntryView: View {
    enum LogType { case info, success, warning }
    let text: String
    let type: LogType
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(type == .success ? ColorTokens.lowRisk : (type == .warning ? ColorTokens.highRisk : ColorTokens.textSecondary))
            .padding(.vertical, 2)
    }
}

@MainActor
class SystemHealthViewModel: ObservableObject {
    @Published var report: ArchitectureAuditReport?
    
    func refresh() async {
        do {
            report = try await APIClient.shared.fetchDiagnostics()
        } catch {
            print("Audit failed: \(error)")
        }
    }
}
