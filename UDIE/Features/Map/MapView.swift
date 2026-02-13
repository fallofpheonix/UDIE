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
    @State private var refreshIconRotation: Double = 0

    enum ActiveSheet {
        case routePlanner
        case eventDetail(GeoEvent)
    }

    @State private var activeSheet: ActiveSheet?

    @StateObject private var viewModel = MapViewModel()

    @State private var routes: [MKRoute] = []
    @State private var selectedRoute: MKRoute?

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090),
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

    var disruptionSummary: [(type: EventType, count: Int)] {
        let grouped = Dictionary(grouping: filteredEvents, by: \.eventType)
        return grouped
            .map { (type: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {

        ZStack {

            // MARK: Map (Clustered)

            ClusteredMapView(
                region: $region,
                events: filteredEvents,
                routes: routes,
                selectedRoute: selectedRoute,
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
                    .transition(.opacity)
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
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            // MARK: Floating Controls

            VStack {
                HStack {
                    if disruptionSummary.isEmpty {
                        Text("No active disruptions in this view")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 3)
                            .transition(.opacity)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                            ForEach(disruptionSummary, id: \.type) { item in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(item.type.displayColor)
                                        .frame(width: 8, height: 8)
                                    Text("\(item.type.displayName): \(item.count)")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                            .padding(.trailing, 6)
                        }
                        .transition(.opacity)
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.85),
                            value: disruptionSummary.map { $0.count }
                        )
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.85),
                            value: disruptionSummary.map { $0.type.rawValue }
                        )
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                HStack {
                    Spacer()

                    VStack(spacing: 16) {

                        if viewModel.isRiskLoading {
                            ProgressView()
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(14)
                                .shadow(radius: 6)
                                .transition(.opacity)
                        } else if let risk = viewModel.routeRisk {

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
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                        Button {
                            showFilters = true
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(BouncyCircleButtonStyle())

                        Button {
                            activeSheet = .routePlanner
                        } label: {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(BouncyCircleButtonStyle())

                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                refreshIconRotation += 360
                            }
                            viewModel.loadEvents(for: region)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .rotationEffect(.degrees(refreshIconRotation))
                        }
                        .buttonStyle(BouncyCircleButtonStyle())
                    }
                    .padding()
                }
            }

            // MARK: Bottom Sheet

            if let sheet = activeSheet {
                let startsExpanded: Bool = {
                    if case .routePlanner = sheet { return true }
                    return false
                }()

                BottomSheet(
                    activeSheet: $activeSheet,
                    initialPosition: startsExpanded ? .expanded : .collapsed
                ) {

                    switch sheet {

                    case .routePlanner:
                        RoutePlannerView(
                            region: $region,
                            routes: $routes,
                            selectedRoute: $selectedRoute,
                            onRouteReady: {
                                activeSheet = nil
                            }
                        )

                    case .eventDetail(let event):
                        EventDetailView(event: event)
                    }
                }
            }
        }
 
        .onChange(of: selectedRoute) { newRoute in
            guard let newRoute else {
                viewModel.clearRisk()
                return
            }
            viewModel.fetchRisk(for: newRoute)
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
        .alert(
            "Data Source Notice",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { show in
                    if !show { viewModel.errorMessage = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onDisappear {
            viewModel.clearRisk()
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: viewModel.isRiskLoading)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: viewModel.routeRisk?.score ?? -1)
        .animation(.easeInOut(duration: 0.2), value: isEmptyState)

    }
}

private struct BouncyCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
