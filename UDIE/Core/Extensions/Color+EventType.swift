//
//  Color+EventType.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import SwiftUI

extension EventType {
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
            return .pink
        }
    }
}
