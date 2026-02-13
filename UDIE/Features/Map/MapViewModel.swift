//
//  MapViewModel.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import Foundation
import Combine
import MapKit
import SwiftUI

@MainActor
final class MapViewModel: ObservableObject {

    @Published var events: [GeoEvent] = []
    @Published var errorMessage: String?
    @Published var routeRisk: RouteRisk?
    @Published var isRiskLoading: Bool = false
    @Published var lastUpdated: Date?

    private let repository = EventRepository()
    private let cityCode = "DEL"
    @Published var isLoading: Bool = false

    private var fetchTask: Task<Void, Never>?
    private var riskTask: Task<Void, Never>?
    private var currentFetchRequestID: UUID?
    private var currentRiskRequestID: UUID?
    private var lastBoundingBox: BoundingBox?

    func loadEvents(for region: MKCoordinateRegion, force: Bool = false) {
        let newBoundingBox = boundingBox(for: region)
        if !force,
           let oldBoundingBox = lastBoundingBox,
           !isSignificantChange(from: oldBoundingBox, to: newBoundingBox) {
            return
        }

        lastBoundingBox = newBoundingBox
        errorMessage = nil

        fetchTask?.cancel()
        let requestID = UUID()
        currentFetchRequestID = requestID

        fetchTask = Task {
            isLoading = true

            try? await Task.sleep(nanoseconds: 600_000_000)

            if Task.isCancelled {
                guard currentFetchRequestID == requestID else { return }
                isLoading = false
                return
            }

            do {
                let fetchedEvents = try await repository.getEvents(
                    minLat: newBoundingBox.minLat,
                    maxLat: newBoundingBox.maxLat,
                    minLng: newBoundingBox.minLng,
                    maxLng: newBoundingBox.maxLng,
                    city: cityCode
                )
                if Task.isCancelled {
                    guard currentFetchRequestID == requestID else { return }
                    isLoading = false
                    return
                }
                guard currentFetchRequestID == requestID else { return }
                events = fetchedEvents
                lastUpdated = Date()
                isLoading = false
            } catch {
                if Task.isCancelled {
                    guard currentFetchRequestID == requestID else { return }
                    isLoading = false
                    return
                }
                guard currentFetchRequestID == requestID else { return }
                #if DEBUG
                print("Events fetch failed:", error.localizedDescription)
                #endif
                errorMessage = "Data source error: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    func fetchRisk(for route: MKRoute) {
        riskTask?.cancel()
        withAnimation(.easeInOut(duration: 0.3)) {
            routeRisk = nil
        }
        isRiskLoading = true

        let requestID = UUID()
        currentRiskRequestID = requestID

        riskTask = Task {
            do {
                let response = try await APIClient.shared.fetchRouteRisk(
                    coordinates: route.polyline.coordinates,
                    city: cityCode
                )

                try Task.checkCancellation()
                guard currentRiskRequestID == requestID else { return }

                let level: RiskLevel
                switch response.level.uppercased() {
                case "HIGH":
                    level = .high
                case "MEDIUM":
                    level = .medium
                default:
                    level = .low
                }

                withAnimation(.easeInOut(duration: 0.3)) {
                    routeRisk = RouteRisk(
                        score: response.score,
                        level: level,
                        distanceKM: route.distance / 1000,
                        durationMinutes: route.expectedTravelTime / 60
                    )
                }
                isRiskLoading = false
            } catch is CancellationError {
                guard currentRiskRequestID == requestID else { return }
                isRiskLoading = false
            } catch {
                guard currentRiskRequestID == requestID else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    routeRisk = nil
                }
                isRiskLoading = false
            }
        }
    }

    func clearRisk() {
        riskTask?.cancel()
        currentRiskRequestID = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            routeRisk = nil
        }
        isRiskLoading = false
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
