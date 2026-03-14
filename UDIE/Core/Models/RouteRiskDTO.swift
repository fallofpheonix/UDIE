import Foundation

struct RouteRiskRequest: Codable {
    let coordinates: [CoordinateDTO]
    let city: String
}

struct CoordinateDTO: Codable {
    let lat: Double
    let lng: Double
}

struct RouteRiskResponse: Decodable {
    let score: Double
    let level: String
    let eventCount: Int

    private enum CodingKeys: String, CodingKey {
        case score
        case level
        case eventCount
        case riskScore
        case cellCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let resolvedScore = try container.decodeIfPresent(Double.self, forKey: .score)
            ?? container.decode(Double.self, forKey: .riskScore)

        score = resolvedScore
        eventCount = try container.decodeIfPresent(Int.self, forKey: .eventCount)
            ?? container.decodeIfPresent(Int.self, forKey: .cellCount)
            ?? 0
        if let explicitLevel = try container.decodeIfPresent(String.self, forKey: .level) {
            level = explicitLevel
        } else {
            switch resolvedScore {
            case 0.66...:
                level = "HIGH"
            case 0.33...:
                level = "MEDIUM"
            default:
                level = "LOW"
            }
        }
    }
}
