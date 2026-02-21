//
//  MapView.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import SwiftUI
import MapKit
import UIKit

extension MKCoordinateRegion: @retroactive Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        let tolerance = 0.00001
        return abs(lhs.center.latitude - rhs.center.latitude) < tolerance &&
        abs(lhs.center.longitude - rhs.center.longitude) < tolerance &&
        abs(lhs.span.latitudeDelta - rhs.span.latitudeDelta) < tolerance &&
        abs(lhs.span.longitudeDelta - rhs.span.longitudeDelta) < tolerance
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

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    private let theme = ThemeManager.default

    var filteredEvents: [GeoEvent] {
        viewModel.events.filter {
            appState.filters.selectedTypes.contains($0.eventType) &&
            $0.severity >= appState.filters.minSeverity &&
            $0.confidence >= appState.filters.minConfidence
        }
    }

    var uiState: MapUIState {
        MapUIState(
            region: region,
            annotations: filteredEvents,
            routePolyline: routes,
            riskLevel: viewModel.routeRisk?.level,
            isLoading: viewModel.isLoading
        )
    }

    private var lastUpdatedText: String {
        guard let date = viewModel.lastUpdated else { return "Not synced yet" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private var isEmptyState: Bool {
        !viewModel.isLoading && filteredEvents.isEmpty
    }

    private var riskViewData: RouteRiskViewData? {
        guard let risk = viewModel.routeRisk else { return nil }
        let eventCount = filteredEvents.count
        let delayMinutes = max(1, Int((risk.durationMinutes * risk.score * 0.25).rounded()))

        let recommendation: String
        switch risk.level {
        case .low:
            recommendation = "Route is operationally stable. Proceed with standard caution."
        case .medium:
            recommendation = "Moderate disruption expected. Keep alternate streets available."
        case .high:
            recommendation = "High disruption density. Prefer reroute before departure."
        }

        return RouteRiskViewData(
            levelTitle: risk.level.title,
            levelColor: risk.level.tokenColor,
            delayEstimate: "~\(delayMinutes) min",
            eventCount: eventCount,
            recommendation: recommendation
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            MapSurfaceView(
                region: $region,
                events: uiState.annotations,
                routes: uiState.routePolyline,
                selectedRoute: selectedRoute,
                onSelect: { event in
                    activeSheet = .eventDetail(event)
                }
            )

            LinearGradient(
                colors: [ColorTokens.mapFadeTop, .clear, ColorTokens.mapFadeBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            if uiState.isLoading {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                ProgressView()
                    .scaleEffect(1.15)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            }

            if isEmptyState {
                VStack {
                    Spacer()
                    Text("No disruptions in this area")
                        .font(.headline)
                        .padding(.horizontal, theme.spacing.lg)
                        .padding(.vertical, theme.spacing.md)
                        .background(ColorTokens.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: theme.elevation.cardRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.elevation.cardRadius, style: .continuous)
                                .stroke(ColorTokens.cardStroke)
                        )
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            }

            VStack(alignment: .leading, spacing: theme.spacing.md) {
                StatusBadgeView(
                    isError: viewModel.errorMessage != nil,
                    eventCount: filteredEvents.count,
                    lastUpdated: lastUpdatedText
                )

                if !filteredEvents.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: theme.spacing.sm) {
                            ForEach(filteredEvents.prefix(5)) { event in
                                EventCellView(event: event)
                                    .frame(width: 210)
                            }
                        }
                    }
                    .transition(.opacity)
                }

                Spacer()

                HStack(alignment: .bottom) {
                    if viewModel.isRiskLoading {
                        ProgressView()
                            .padding(theme.spacing.md)
                            .background(ColorTokens.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: theme.elevation.cardRadius, style: .continuous))
                    } else if let riskViewData {
                        RiskSummaryCard(model: riskViewData) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedRoute = nil
                                routes = []
                            }
                            viewModel.clearRisk()
                        }
                        .frame(width: 300)
                        .transition(.opacity)
                    }

                    Spacer()

                    VStack(spacing: theme.spacing.sm) {
                        FloatingButton(systemName: "line.3.horizontal.decrease.circle") {
                            showFilters = true
                        }

                        FloatingButton(systemName: "arrow.triangle.turn.up.right.diamond.fill") {
                            activeSheet = .routePlanner
                        }

                        FloatingButton(systemName: "arrow.clockwise") {
                            viewModel.loadEvents(for: region, force: true)
                        }
                    }
                }
            }
            .padding(.horizontal, theme.spacing.md)
            .padding(.top, theme.spacing.md)
            .padding(.bottom, theme.spacing.lg)

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
                        RouteInputSheet(
                            region: $region,
                            routes: $routes,
                            selectedRoute: $selectedRoute,
                            onRouteRequested: {
                                activeSheet = nil
                            }
                        )
                    case .eventDetail(let event):
                        EventDetailModal(event: event)
                    }
                }
            }
        }
        .onChange(of: selectedRoute) { _, newRoute in
            guard let newRoute else {
                viewModel.clearRisk()
                return
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.fetchRisk(for: newRoute)
        }
        .onChange(of: region) { _, newRegion in
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
            Button("Retry") {
                viewModel.errorMessage = nil
                viewModel.loadEvents(for: region, force: true)
            }
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onDisappear {
            viewModel.clearRisk()
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.18), value: viewModel.isRiskLoading)
        .animation(.easeInOut(duration: 0.18), value: viewModel.routeRisk?.score ?? -1)
        .tint(ColorTokens.neutralAccent)
    }
}
