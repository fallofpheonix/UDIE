import Foundation

// MARK: - City Dashboard
struct CityDashboardResponse: Codable {
    let heatmapSummary: HeatmapSummaryDTO
    let topHotspots: [HotspotDTO]
    let recentIncidents: [RecentIncidentDTO]
    let cityRiskTrend: [RiskTrendDTO]
}

struct HeatmapSummaryDTO: Codable {
    let cells: Int
    let avgRisk: Double
    let maxRisk: Double
    
    enum CodingKeys: String, CodingKey {
        case cells
        case avgRisk = "avg_risk"
        case maxRisk = "max_risk"
    }
}

struct HotspotDTO: Codable {
    let rank: Int
    let aggregatedRisk: Double
    let peakRisk: Double
    let cellCount: Int
    let cells: [String]
}

struct RecentIncidentDTO: Codable {
    let eventType: String
    let severity: Double
    let confidence: Double
    let lat: Double
    let lng: Double
    let observedAt: String
}

struct RiskTrendDTO: Codable {
    let snapshotTime: String
    let avgRisk: Double
    let maxRisk: Double
}

// MARK: - Cell Insight
struct CellInsightResponse: Codable {
    let h3Index: String
    let riskScore: Double
    let dominantEventType: String
    let recentEventCount: Int
    let reliabilityScore: Double
    let forecastProbability: Double
    let updatedAt: String?
}

// MARK: - Risk Snapshots
struct RiskSnapshotDTO: Codable {
    let snapshotTime: String
    let h3Index: String
    let riskWeight: Double
}

struct RiskSnapshotsResponse: Codable {
    let snapshots: [RiskSnapshotDTO]
}

// MARK: - Diagnostics
struct ArchitectureAuditReport: Codable {
    let status: String
    let checks: [String: [String: AnyCodable]]
    let generatedAt: String
}

// Helper for dynamic dictionary decoding
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Bool.self) {
            value = x
        } else if let x = try? container.decode(Int.self) {
            value = x
        } else if let x = try? container.decode(Double.self) {
            value = x
        } else if let x = try? container.decode(String.self) {
            value = x
        } else if let x = try? container.decode([String: AnyCodable].self) {
            value = x.mapValues { $0.value }
        } else if let x = try? container.decode([AnyCodable].self) {
            value = x.map { $0.value }
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Not a JSON type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let x = value as? Bool {
            try container.encode(x)
        } else if let x = value as? Int {
            try container.encode(x)
        } else if let x = value as? Double {
            try container.encode(x)
        } else if let x = value as? String {
            try container.encode(x)
        } else if let x = value as? [String: Any] {
            try container.encode(x.mapValues { AnyCodable($0) })
        } else if let x = value as? [Any] {
            try container.encode(x.map { AnyCodable($0) })
        } else {
            // Encode null if it's something else
            try container.encodeNil()
        }
    }
}
