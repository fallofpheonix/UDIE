import SwiftUI
import Foundation
import MapKit

enum RiskLevel: Int, CaseIterable, Identifiable {
    case low = 0
    case medium
    case high

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .low:
            return "Low Risk"
        case .medium:
            return "Medium Risk"
        case .high:
            return "High Risk"
        }
    }

    var color: Color {
        switch self {
        case .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .red
        }
    }
}

struct RouteRisk: Identifiable {
    let id = UUID()
    let routeName: String
    let riskLevel: RiskLevel
    let coordinates: [CLLocationCoordinate2D]

    // Computed properties to support UI
    var title: String {
        "\(routeName) - \(riskLevel.title)"
    }

    var color: Color {
        riskLevel.color
    }
}
