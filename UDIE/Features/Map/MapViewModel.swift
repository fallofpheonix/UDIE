//
//  MapViewModel.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import Foundation
import Combine
import MapKit

@MainActor
final class MapViewModel: ObservableObject {

    @Published var events: [GeoEvent] = []
    @Published var errorMessage: String?

    private let repository = EventRepository()
    @Published var isLoading: Bool = false

    private var fetchTask: Task<Void, Never>?
    private var lastBoundingBox: BoundingBox?

    func loadEvents(for region: MKCoordinateRegion) {
        let newBoundingBox = boundingBox(for: region)
        if let oldBoundingBox = lastBoundingBox,
           !isSignificantChange(from: oldBoundingBox, to: newBoundingBox) {
            return
        }

        lastBoundingBox = newBoundingBox
        errorMessage = nil

        fetchTask?.cancel()

        fetchTask = Task {
            isLoading = true

            try? await Task.sleep(nanoseconds: 600_000_000)

            if Task.isCancelled {
                isLoading = false
                return
            }

            do {
                let fetchedEvents = try await repository.getEvents(
                    minLat: newBoundingBox.minLat,
                    maxLat: newBoundingBox.maxLat,
                    minLng: newBoundingBox.minLng,
                    maxLng: newBoundingBox.maxLng
                )
                if Task.isCancelled {
                    isLoading = false
                    return
                }
                events = fetchedEvents
                isLoading = false
            } catch {
                if Task.isCancelled {
                    isLoading = false
                    return
                }
                errorMessage = "Unable to fetch events from backend."
                isLoading = false
            }
        }
    }

    func fetchRisk(for route: MKRoute) async throws -> RouteRisk {
        let response = try await APIClient.shared.fetchRouteRisk(
            coordinates: route.polyline.coordinates,
            city: "BLR"
        )

        let level: RiskLevel
        switch response.level.uppercased() {
        case "HIGH":
            level = .high
        case "MEDIUM":
            level = .medium
        default:
            level = .low
        }

        return RouteRisk(
            score: response.score,
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

    private func boundingBox(for region: MKCoordinateRegion) -> BoundingBox {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLng = region.center.longitude - region.span.longitudeDelta / 2
        let maxLng = region.center.longitude + region.span.longitudeDelta / 2
        return BoundingBox(minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng)
    }
}
