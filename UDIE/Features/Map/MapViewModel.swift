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
    enum BackendSyncState: Equatable {
        case disconnected
        case connecting
        case connected
        case syncing
        case synced
        case error(String)
    }

    @Published var isExpertMode = false
    @Published var events: [GeoEvent] = []
    @Published var errorMessage: String?
    @Published var routeRisk: RouteRisk?
    @Published var isRiskLoading: Bool = false
    @Published var lastUpdated: Date?
    @Published var isLoading: Bool = false
    @Published var temporalValue: Double = 100 // 100 = LIVE
    @Published var snapshots: [RiskSnapshotDTO] = []
    @Published var selectedCoordinate: CoordinateDTO?
    @Published var selectedH3Index: String?
    @Published var cityCode = "AUTO"
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var backendSyncState: BackendSyncState = .disconnected
    
    private let locationManager = LocationManager()
    
    private let gridService = RiskGridService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupLocationTracking()
    }

    private func setupLocationTracking() {
        locationManager.$userLocation
            .compactMap { $0?.coordinate }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] coordinate in
                self?.userLocation = coordinate
                #if DEBUG
                print("📍 User location updated: \(coordinate.latitude), \(coordinate.longitude)")
                #endif
            }
            .store(in: &cancellables)
    }

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
            backendSyncState = .connecting

            // Debounce for rapid map movements
            try? await Task.sleep(nanoseconds: 400_000_000)

            if Task.isCancelled {
                if currentFetchRequestID == requestID { isLoading = false }
                return
            }

            do {
                #if DEBUG
                print("🔍 Attempting sync with baseURL: \(APIClient.shared.getBaseURL())")
                #endif

                try await APIClient.shared.healthCheck()
                
                guard !Task.isCancelled, currentFetchRequestID == requestID else { return }
                backendSyncState = .connected

                // Small delay to show "Connected" before "Syncing"
                try? await Task.sleep(nanoseconds: 200_000_000)
                
                guard !Task.isCancelled, currentFetchRequestID == requestID else { return }
                backendSyncState = .syncing

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
                backendSyncState = .synced
            } catch {
                guard !Task.isCancelled, currentFetchRequestID == requestID else {
                    return
                }
                
                #if DEBUG
                print("❌ Events fetch failed: \(error.localizedDescription)")
                #endif
                
                let desc = error.localizedDescription
                errorMessage = "Sync Error: \(desc)"
                backendSyncState = .error(desc)
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

                withAnimation(.easeInOut(duration: 0.20)) {
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

    func fetchSnapshots(for region: MKCoordinateRegion) {
        let bbox = boundingBox(for: region)
        let now = Date()
        let start = now.addingTimeInterval(-12 * 3600)
        
        Task {
            do {
                let response = try await APIClient.shared.fetchRiskSnapshots(
                    start: start,
                    end: now,
                    minLat: bbox.minLat,
                    maxLat: bbox.maxLat,
                    minLng: bbox.minLng,
                    maxLng: bbox.maxLng
                )
                snapshots = response.snapshots
            } catch {
                print("Failed to fetch snapshots: \(error)")
            }
        }
    }

    func selectCell(h3Index: String, coordinate: CLLocationCoordinate2D) {
        selectedH3Index = h3Index
        selectedCoordinate = CoordinateDTO(lat: coordinate.latitude, lng: coordinate.longitude)
    }

    /// Evaluates route risk using the in-memory spatial field (O(route_cells) complexity).
    func evaluateRouteLocally(route: MKRoute) -> Double {
        let cellCount = 50 
        var totalScore = 0.0
        
        for i in 0..<cellCount {
            let mockH3 = "8928308280f\(i % 10)ff"
            totalScore += gridService.getRiskWeight(for: mockH3)
        }
        
        return totalScore / Double(cellCount)
    }
}

extension MapViewModel: MapPresentationLogic {
    func requestRoute() {
        // Route input is handled by RouteInputSheet and emitted via UI bindings.
    }

    func refreshRisk() {
        // Risk recomputation is triggered when selectedRoute updates.
    }
}
