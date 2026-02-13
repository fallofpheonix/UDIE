//
//  RouteRisk.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import SwiftUI

struct RouteRisk {

    let score: Double
    let level: RiskLevel
    let distanceKM: Double
    let durationMinutes: Double
}

enum RiskLevel {
    case low
    case medium
    case high

    var color: LinearGradient {
        switch self {
        case .low:
            return LinearGradient(
                colors: [.green.opacity(0.8), .green],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .medium:
            return LinearGradient(
                colors: [.orange.opacity(0.8), .orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .high:
            return LinearGradient(
                colors: [.red.opacity(0.8), .red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
