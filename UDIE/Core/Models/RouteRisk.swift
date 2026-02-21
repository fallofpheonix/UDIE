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
                colors: [ColorTokens.lowRisk.opacity(0.85), ColorTokens.lowRisk],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .medium:
            return LinearGradient(
                colors: [ColorTokens.mediumRisk.opacity(0.85), ColorTokens.mediumRisk],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .high:
            return LinearGradient(
                colors: [ColorTokens.highRisk.opacity(0.85), ColorTokens.highRisk],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var tokenColor: Color {
        switch self {
        case .low:
            return ColorTokens.lowRisk
        case .medium:
            return ColorTokens.mediumRisk
        case .high:
            return ColorTokens.highRisk
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
