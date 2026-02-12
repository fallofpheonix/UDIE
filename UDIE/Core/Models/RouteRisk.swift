//
//  RouteRisk.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import SwiftUI

struct RouteRisk {
    print("Risk score:", normalized)

    let score: Double
    let level: RiskLevel
    let distanceKM: Double
    let durationMinutes: Double
}

enum RiskLevel {
    case low
    case medium
    case high

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    var title: String {
        switch self {
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        }
    }
}
