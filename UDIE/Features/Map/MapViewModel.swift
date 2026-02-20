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
    @Published var isLoading: Bool = false

    var cityCode = "DEL" // Default, can be updated via location logic

    private let repository = EventRepository()
    private var fetchTask: Task<Void, Never>?
    private var riskTask: Task<Void, Never>?
    private var currentFetchRequestID: UUID?
    private var currentRiskRequestID: UUID?
    private var lastBoundingBox: BoundingBox?

    func setCity(_ code: String) {
        let normalized = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized != cityCode else { return }
        cityCode = normalized
        #if DEBUG
        print("🏙️ City switched to: \(normalized)")
        #endif
    }

    func loadEvents(for region: MKCoordinateRegion, force: Bool = false) {
        let newBoundingBox = boundingBox(for: region)
        if !force,
           let oldBoundingBox = lastBoundingBox,
           !isSignificantChange(from: oldBoundingBox, to: newBoundingBox) {
            return
        }

        lastBoundingBox = newBoundingBox
        
        // Only clear error if we are force refreshing or it was a connectivity error
        if force { errorMessage = nil }

        fetchTask?.cancel()
        let requestID = UUID()
        currentFetchRequestID = requestID

        fetchTask = Task {
            isLoading = true

            // Debounce for rapid map movements
            try? await Task.sleep(nanoseconds: 400_000_000)

            if Task.isCancelled {
                if currentFetchRequestID == requestID { isLoading = false }
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
                
                guard !Task.isCancelled, currentFetchRequestID == requestID else {
                    return
                }
                
                events = fetchedEvents
                lastUpdated = Date()
                errorMessage = nil
            } catch {
                guard !Task.isCancelled, currentFetchRequestID == requestID else {
                    return
                }
                
                #if DEBUG
                print("❌ Events fetch failed: \(error.localizedDescription)")
                #endif
                
                // Keep existing events but show a warning
                errorMessage = "Sync Error: \(error.localizedDescription)"
            }
            isLoading = false
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

                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    routeRisk = RouteRisk(
                        score: response.score,
                        level: level,
                        distanceKM: route.distance / 1000,
                        durationMinutes: route.expectedTravelTime / 60
                    )
                }
            } catch is CancellationError {
                // Ignore
            } catch {
                guard currentRiskRequestID == requestID else { return }
                #if DEBUG
                print("❌ Risk fetch failed: \(error.localizedDescription)")
                #endif
                errorMessage = "Risk service unavailable"
            }
            isRiskLoading = false
        }
    }

    func clearRisk() {
        riskTask?.cancel()
        currentRiskRequestID = nil
        withAnimation(.easeInOut(duration: 0.2)) {
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

        // Threshold optimized for mobile viewport
        let movementThreshold = oldSpan * 0.15 
        let zoomThreshold = oldSpan * 0.20

        return latShift > movementThreshold ||
               lngShift > movementThreshold ||
               zoomShift > zoomThreshold
    }

    private func boundingBox(for region: MKCoordinateRegion) -> BoundingBox {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLng = region.center.longitude - region.span.longitudeDelta / 2
        let maxLng = region.center.longitude + region.span.longitudeDelta / 2
        return BoundingBox(minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng)
    }
}
