import Foundation

struct RouteRiskRequest: Codable {
    let coordinates: [CoordinateDTO]
    let city: String
}

struct CoordinateDTO: Codable {
    let lat: Double
    let lng: Double
}

struct RouteRiskResponse: Codable {
    let score: Double
    let level: String
    let eventCount: Int
}
