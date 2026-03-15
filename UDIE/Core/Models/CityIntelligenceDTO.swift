import Foundation

// MARK: - City Dashboard
struct CityDashboardResponse: Decodable {
    let heatmapSummary: HeatmapSummaryDTO
    let topHotspots: [HotspotDTO]
    let recentIncidents: [RecentIncidentDTO]
    let cityRiskTrend: [RiskTrendDTO]
}

struct HeatmapSummaryDTO: Decodable {
    let cells: Int
    let avgRisk: Double
    let maxRisk: Double

    enum CodingKeys: String, CodingKey {
        case cells
        case avgRisk = "avg_risk"
        case maxRisk = "max_risk"
        case avgRiskCamel = "avgRisk"
        case maxRiskCamel = "maxRisk"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cells = try container.decode(Int.self, forKey: .cells)
        avgRisk = try container.decodeIfPresent(Double.self, forKey: .avgRisk)
            ?? container.decodeIfPresent(Double.self, forKey: .avgRiskCamel)
            ?? 0
        maxRisk = try container.decodeIfPresent(Double.self, forKey: .maxRisk)
            ?? container.decodeIfPresent(Double.self, forKey: .maxRiskCamel)
            ?? 0
    }
}

struct HotspotDTO: Decodable {
    let rank: Int
    let aggregatedRisk: Double
    let peakRisk: Double
    let cellCount: Int
    let cells: [String]
}

struct RecentIncidentDTO: Decodable {
    let eventType: String
    let severity: Double
    let confidence: Double
    let lat: Double
    let lng: Double
    let observedAt: String
}

struct RiskTrendDTO: Decodable {
    let snapshotTime: String
    let avgRisk: Double
    let maxRisk: Double
}

// MARK: - Cell Insight
struct CellInsightResponse: Decodable {
    let h3Index: String
    let riskScore: Double
    let dominantEventType: String
    let recentEventCount: Int
    let reliabilityScore: Double
    let forecastProbability: Double
    let updatedAt: String?
}

// MARK: - Risk Snapshots
struct RiskSnapshotDTO: Decodable {
    let snapshotTime: String
    let h3Index: String
    let riskWeight: Double
    let eventCount: Int
    let dominantHazard: String?
    let boundary: [CoordinateDTO]?

    enum CodingKeys: String, CodingKey {
        case snapshotTime
        case snapshotTimeSnake = "snapshot_time"
        case h3Index
        case h3IndexSnake = "h3_index"
        case riskWeight
        case riskWeightSnake = "risk_weight"
        case eventCount
        case dominantHazard
        case boundary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        snapshotTime = try container.decodeIfPresent(String.self, forKey: .snapshotTime)
            ?? container.decodeIfPresent(String.self, forKey: .snapshotTimeSnake)
            ?? ""
        h3Index = try container.decodeIfPresent(String.self, forKey: .h3Index)
            ?? container.decode(String.self, forKey: .h3IndexSnake)
        riskWeight = try container.decodeIfPresent(Double.self, forKey: .riskWeight)
            ?? container.decodeIfPresent(Double.self, forKey: .riskWeightSnake)
            ?? 0
        eventCount = try container.decodeIfPresent(Int.self, forKey: .eventCount) ?? 0
        dominantHazard = try container.decodeIfPresent(String.self, forKey: .dominantHazard)
        boundary = try container.decodeIfPresent([CoordinateDTO].self, forKey: .boundary)
    }
}

struct RiskSnapshotsResponse: Decodable {
    let snapshots: [RiskSnapshotDTO]

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let directSnapshots = try? single.decode([RiskSnapshotDTO].self) {
            snapshots = directSnapshots
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        snapshots = try container.decode([RiskSnapshotDTO].self, forKey: .snapshots)
    }

    private enum CodingKeys: String, CodingKey {
        case snapshots
    }
}

// MARK: - Diagnostics
struct ArchitectureAuditReport: Decodable {
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
