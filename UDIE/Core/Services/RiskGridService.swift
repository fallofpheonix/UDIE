import Foundation
import Combine

/// Role: High-throughput in-memory spatial risk field.
/// Implements the UDIE production physics kernels for real-time evaluation.
/// Governed by the UDIE Full Production Equation: 
/// R(x,t) = [Σ Ai log(1+si) ci exp(-d/λ) exp(-t/τ)] * [1 + α log(1 + ρ)] * exp(-I/k)
class RiskGridService: ObservableObject {
    static let shared = RiskGridService()
    
    struct GridEntry {
        var risk: Double
        var density: Double
        var reliability: Double
        var aiSuggestion: String?
        var timestamp: Date
    }
    
    // In-memory grid: H3 Index -> Model Data
    @Published private(set) var riskGrid: [String: GridEntry] = [:]
    
    // Global Coefficients (Simplified for lookup layer)
    private let alpha = 0.5 // Density amplification
    private let k_scaling = 2.0 // Reliability scaling
    
    // Observability metrics
    @Published private(set) var gridMemoryUsageBytes: Int = 0
    @Published private(set) var lastSyncTimestamp: Date?
    @Published private(set) var queriesPerSecond: Double = 0
    
    private var queryCount: Int = 0
    private var timer: AnyCancellable?
    
    private init() {
        startMetricsTimer()
    }
    
    /// O(1) lookup for a specific cell's fully computed risk.
    /// Simplified to trust backend's pre-computed/pre-decayed weights.
    func getRiskWeight(for h3Index: String) -> Double {
        queryCount += 1
        guard let entry = riskGrid[h3Index] else { return 0.0 }
        
        // 1. Base Field (Now trusted as pre-processed by backend)
        // 2. Density Amplification: [1 + α log(1 + ρ)]
        let densityTerm = 1.0 + alpha * log1p(entry.density)
        
        // 3. Reliability Modifier: exp(-I / k)
        let reliabilityTerm = exp(-entry.reliability / k_scaling)
        
        // NOTE: Temporal decay is now handled by the backend materialization cycle
        // to ensure architectural alignment with the "Weather Model".
        
        return entry.risk * densityTerm * reliabilityTerm
    }
    
    /// Streaming update functionality.
    func updateGrid(with updates: [String: (intensity: Double, density: Double, reliability: Double, aiSuggestion: String?, timestamp: Date)]) {
        for (index, data) in updates {
            riskGrid[index] = GridEntry(
                risk: data.intensity,
                density: data.density,
                reliability: data.reliability,
                aiSuggestion: data.aiSuggestion,
                timestamp: data.timestamp
            )
        }
        
        lastSyncTimestamp = Date()
        calculateMemoryUsage()
    }
    
    func resetGrid() {
        riskGrid.removeAll()
        calculateMemoryUsage()
    }
    
    private func calculateMemoryUsage() {
        // Entry size: GridEntry is ~56 bytes + Map overhead
        gridMemoryUsageBytes = riskGrid.count * 160
    }
    
    private func startMetricsTimer() {
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.queriesPerSecond = Double(self.queryCount)
                self.queryCount = 0
            }
    }
}
