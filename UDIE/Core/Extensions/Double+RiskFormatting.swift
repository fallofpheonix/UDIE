//
//  Double+RiskFormatting.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import Foundation

extension Double {

    var riskPercentage: String {
        "\(Int(self * 100))%"
    }

    var riskLevel: String {
        switch self {
        case 0..<0.33:
            return "Low"
        case 0.33..<0.66:
            return "Medium"
        default:
            return "High"
        }
    }
}
