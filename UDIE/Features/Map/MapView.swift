//
//  MapView.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//


import SwiftUI
import MapKit

extension MKCoordinateRegion: Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        lhs.center.latitude == rhs.center.latitude &&
        lhs.center.longitude == rhs.center.longitude &&
        lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
        lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }
}

struct MapView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locationManager: LocationManager
    @State private var showFilters = false

    enum ActiveSheet {
        case routePlanner
        case eventDetail(GeoEvent)
    }

    @State private var activeSheet: ActiveSheet?

    @StateObject private var viewModel = MapViewModel()

    @State private var routes: [MKRoute] = []
    @State private var selectedRoute: MKRoute?
    @State private var routeRisk: RouteRisk?

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    var isEmptyState: Bool {
        !viewModel.isLoading && filteredEvents.isEmpty
    }

    var filteredEvents: [GeoEvent] {
        viewModel.events.filter {
            appState.filters.selectedTypes.contains($0.eventType) &&
            $0.severity >= appState.filters.minSeverity &&
            $0.confidence >= appState.filters.minConfidence
        }
    }

    var body: some View {

        ZStack {

            // MARK: Map (Clustered)

            ClusteredMapView(
                region: $region,
                events: filteredEvents,
                onSelect: { event in
                    activeSheet = .eventDetail(event)
                }
            )

            .ignoresSafeArea()
            if viewModel.isLoading {

                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                ProgressView()
                    .scaleEffect(1.4)
            }

            if isEmptyState {

                VStack(spacing: 12) {

                    Image(systemName: "exclamationmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text("No disruptions in this area")
                        .font(.headline)

                    Text("Try zooming out or adjusting filters")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }

            // MARK: Floating Controls

            VStack {
                Spacer()

                HStack {
                    Spacer()

                    VStack(spacing: 16) {

                        if let risk = routeRisk {

                            VStack(alignment: .leading, spacing: 8) {

                                Text(risk.level.title)
                                    .font(.headline)
                                    .foregroundColor(.white)

                                ProgressView(value: risk.score)
                                    .tint(.white)

                                HStack {
                                    Text(String(format: "%.1f km", risk.distanceKM))
                                    Spacer()
                                    Text(String(format: "%.0f min", risk.durationMinutes))
                                }
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                            }
                            .padding()
                            .background(risk.level.color)
                            .cornerRadius(14)
                            .shadow(radius: 6)
                        }
                        Button {
                            showFilters = true
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        Button {
                            activeSheet = .routePlanner
                        } label: {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        Button {
                            viewModel.loadEvents(for: region)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                }
            }

            // MARK: Bottom Sheet

            if let sheet = activeSheet {

                BottomSheet(activeSheet: $activeSheet) {

                    switch sheet {

                    case .routePlanner:
                        RoutePlannerView(
                            region: $region,
                            routes: $routes,
                            selectedRoute: $selectedRoute
                        )

                    case .eventDetail(let event):
                        EventDetailView(event: event)
                    }
                }
            }
        }
 
        .onChange(of: selectedRoute) { newRoute in
            guard let newRoute else {
                routeRisk = nil
                return
            }
            routeRisk = viewModel.calculateRisk(for: newRoute)
        }

        .onChange(of: region) { newRegion in
            viewModel.loadEvents(for: newRegion)
        }


        .onAppear {
            locationManager.requestPermission()
            viewModel.loadEvents(for: region)
        }
        .sheet(isPresented: $showFilters) {
            FilterView()
                .environmentObject(appState)
        }

    }
}
