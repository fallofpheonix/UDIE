import SwiftUI
import Foundation

struct EventListCardViewData: Identifiable {
    let id: UUID
    let title: String
    let severityLabel: String
    let confidenceText: String
    let distanceText: String
    let coordinateText: String
    let tint: Color
    let background: Color

    static func from(event: GeoEvent, distanceText: String = "Near route") -> EventListCardViewData {
        let confidence = Int((event.confidence * 100).rounded())
        let background: Color
        switch event.eventType {
        case .accident, .construction:
            background = ColorTokens.surfaceTintedC
        case .flood:
            background = ColorTokens.surfaceTintedA
        case .protest:
            background = ColorTokens.surfaceTintedB
        case .heavyTraffic:
            background = ColorTokens.surfaceSecondary
        }

        return EventListCardViewData(
            id: event.id,
            title: event.eventType.displayName,
            severityLabel: "S\(event.severity)",
            confidenceText: "Confidence \(confidence)%",
            distanceText: distanceText,
            coordinateText: String(format: "%.4f, %.4f", event.latitude, event.longitude),
            tint: event.eventType.displayColor,
            background: background
        )
    }
}
