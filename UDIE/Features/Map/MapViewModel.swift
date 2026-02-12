//
//  MapViewModel.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import Foundation
import MapKit

@MainActor
final class MapViewModel: ObservableObject {

    @Published var events: [GeoEvent] = []

    private let repository = EventRepository()
    @Published var isLoading: Bool = false

    private var fetchTask: Task<Void, Never>?
    private var lastBoundingBox: BoundingBox?

    func loadEvents(for region: MKCoordinateRegion) {

        fetchTask?.cancel()

        fetchTask = Task {

            isLoading = true

            try? await Task.sleep(nanoseconds: 600_000_000)

            if Task.isCancelled { return }

            let generated = MockEventGenerator.generate(in: region)

            self.events = generated

            isLoading = false
        }
    }

    func calculateRisk(for route: MKRoute) -> RouteRisk {

        var totalRisk: Double = 0
        let coordinates = route.polyline.coordinates

        for event in events {
            for point in coordinates {
                let distance = event.coordinate.distance(to: point)
                if distance < 300 {
                    totalRisk += Double(event.severity) * event.confidence
                    break
                }
            }
        }

        let normalized = min(totalRisk / 10.0, 1.0)

        let level: RiskLevel

        switch normalized {
        case 0..<0.33:
            level = .low
        case 0.33..<0.66:
            level = .medium
        default:
            level = .high
        }

        return RouteRisk(
            score: normalized,
            level: level,
            distanceKM: route.distance / 1000,
            durationMinutes: route.expectedTravelTime / 60
        )
    }




    private func isSignificantChange(
        from old: BoundingBox,
        to new: BoundingBox
    ) -> Bool {

        let latShift = abs(old.minLat - new.minLat)
        let lngShift = abs(old.minLng - new.minLng)

        let oldSpan = old.maxLat - old.minLat
        let newSpan = new.maxLat - new.minLat

        let zoomShift = abs(oldSpan - newSpan)

        let threshold = 0.01

        return latShift > threshold ||
               lngShift > threshold ||
               zoomShift > threshold
    }
}
