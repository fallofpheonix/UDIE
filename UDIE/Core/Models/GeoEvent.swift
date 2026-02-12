//
//  GeoEvent.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import Foundation
import SwiftUI
import CoreLocation

struct GeoEvent: Identifiable, Codable {

    let id: UUID
    let eventType: EventType
    let severity: Int
    let confidence: Double
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case eventType = "event_type"
        case severity
        case confidence
        case latitude
        case longitude
    }
}

enum EventType: String, Codable, CaseIterable {
    var displayColor: Color {
        switch self {
        case .accident:
            return .red
        case .construction:
            return .orange
        case .flood:
            return .blue
        case .protest:
            return .purple
        case .heavyTraffic:
            return .yellow
        }
    }

    case accident
    case construction
    case flood
    case protest
    case heavyTraffic = "heavy_traffic"

    var displayName: String {
        switch self {
        case .accident: return "Accident"
        case .construction: return "Construction"
        case .flood: return "Flood"
        case .protest: return "Protest"
        case .heavyTraffic: return "Heavy Traffic"
        }
    }
}
