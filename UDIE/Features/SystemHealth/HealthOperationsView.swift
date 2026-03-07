import SwiftUI
import Combine

struct HealthOperationsView: View {
    @StateObject private var viewModel = HealthViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                ColorTokens.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Architecture Audit Status
                        auditStatusHeader
                        
                        // 2. Performance Metrics Grid
                        metricsGrid
                        
                        // 3. Service Health List
                        serviceHealthList
                    }
                    .padding()
                }
            }
            .navigationTitle("System Health")
            .onAppear {
                Task { await viewModel.runDiagnostics() }
            }
        }
    }
    
    private var auditStatusHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.isAuditPassed ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(viewModel.isAuditPassed ? ColorTokens.lowRisk : ColorTokens.highRisk)
            
            Text("Architecture Audit")
                .font(.headline)
            
            Text(viewModel.isAuditPassed ? "STATUS: HEALTHY" : "STATUS: CRITICAL")
                .font(.subheadline.bold())
                .foregroundStyle(viewModel.isAuditPassed ? ColorTokens.lowRisk : ColorTokens.highRisk)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(viewModel.isAuditPassed ? ColorTokens.lowRisk.opacity(0.1) : ColorTokens.highRisk.opacity(0.1))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(ColorTokens.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var metricsGrid: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                metricCard(title: "Risk Latency", value: "\(viewModel.latency) ms", icon: "timer")
                metricCard(title: "Refresh Cycle", value: "\(viewModel.refreshCycle) m", icon: "arrow.clockwise")
            }
            HStack(spacing: 16) {
                metricCard(title: "Replica Lag", value: "\(viewModel.replicationLag) ms", icon: "clock.arrow.2.circlepath")
                metricCard(title: "Status", value: "Healthy", icon: "checkmark.circle")
            }
        }
    }
    
    private var serviceHealthList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Service Connectivity")
                .font(.headline)
            
            ForEach(viewModel.services) { service in
                HStack {
                    Image(systemName: service.icon)
                        .foregroundStyle(ColorTokens.accent)
                        .frame(width: 24)
                    Text(service.title)
                        .font(.subheadline)
                    Spacer()
                    Circle()
                        .fill(service.statusColor)
                        .frame(width: 10, height: 10)
                }
                .padding()
                .background(ColorTokens.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private func metricCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(ColorTokens.accent)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ColorTokens.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Models

struct ServiceStatus: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let statusColor: Color
}

@MainActor
final class HealthViewModel: ObservableObject {
    @Published var isAuditPassed = true
    @Published var latency = 0.8
    @Published var refreshCycle = 5
    @Published var replicationLag = 120
    @Published var services: [ServiceStatus] = [
        ServiceStatus(title: "Spatial Partition Engine", icon: "square.grid.3x3.fill", statusColor: ColorTokens.lowRisk),
        ServiceStatus(title: "Risk Surface Materialization", icon: "bolt.fill", statusColor: ColorTokens.lowRisk),
        ServiceStatus(title: "Forecast Model Server", icon: "cloud.sun.fill", statusColor: ColorTokens.mediumRisk),
        ServiceStatus(title: "Event Lifecycle Manager", icon: "leaf.fill", statusColor: ColorTokens.lowRisk)
    ]
    
    func runDiagnostics() async {
        // Mocking diagnostic run
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
}
