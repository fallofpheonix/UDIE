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

    private var eventCardModels: [EventListCardViewData] {
        filteredEvents.prefix(6).map { event in
            EventListCardViewData.from(event: event, distanceText: nearbyLabel(for: event))
        }
    }

    private var riskViewData: RouteRiskViewData? {
        guard let risk = viewModel.routeRisk else { return nil }

        let eventCount = filteredEvents.count
        let delayMinutes = max(1, Int((risk.durationMinutes * risk.score * 0.25).rounded()))
        let etaMinutes = max(1, Int(risk.durationMinutes.rounded()))
        let distanceKM = String(format: "%.1f km", risk.distanceKM)
        let arrivalDate = Date().addingTimeInterval(risk.durationMinutes * 60)
        let arrivalFormatter = DateFormatter()
        arrivalFormatter.timeStyle = .short
        arrivalFormatter.dateStyle = .none
        let arrivalText = arrivalFormatter.string(from: arrivalDate)

        let primaryInstruction = selectedRoute?.steps.first(where: { !$0.instructions.isEmpty })?.instructions ?? "Proceed on selected route"
        let secondaryInstruction = "Risk-aware guidance from live disruptions"

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
            etaText: "\(etaMinutes) min",
            distanceText: distanceKM,
            arrivalText: arrivalText,
            primaryInstruction: primaryInstruction,
            secondaryInstruction: secondaryInstruction,
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
                ColorTokens.mapOverlaySoft
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            }

            if isEmptyState {
                VStack {
                    Spacer()
                    Text("No disruptions in this area")
                        .font(.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .padding(.horizontal, theme.spacing.lg)
                        .padding(.vertical, theme.spacing.md)
                        .background(ColorTokens.surfacePrimary)
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

            VStack(alignment: .leading, spacing: theme.spacing.md2) {
                StatusBadgeView(
                    isError: viewModel.errorMessage != nil,
                    eventCount: filteredEvents.count,
                    lastUpdated: lastUpdatedText
                )
                .transition(.opacity.combined(with: .move(edge: .top)))

                if viewModel.isRiskLoading {
                    HStack {
                        ProgressView()
                        Text("Analyzing route risk")
                            .font(.subheadline)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .padding(theme.spacing.sm)
                    .background(ColorTokens.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.pillRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ElevationTokens.pillRadius, style: .continuous)
                            .stroke(ColorTokens.cardStroke)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else if let riskViewData {
                    RiskSummaryCard(model: riskViewData) {
                        withAnimation(.easeInOut(duration: 0.20)) {
                            selectedRoute = nil
                            routes = []
                        }
                        viewModel.clearRisk()
                    }
                    .frame(maxWidth: 430)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()

                if !eventCardModels.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: theme.spacing.sm) {
                            ForEach(eventCardModels) { model in
                                EventCellView(model: model)
                                    .frame(width: 244)
                                    .onTapGesture {
                                        if let event = filteredEvents.first(where: { $0.id == model.id }) {
                                            activeSheet = .eventDetail(event)
                                        }
                                    }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                HStack(alignment: .bottom, spacing: theme.spacing.sm) {
                    HStack(spacing: theme.spacing.sm) {
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
                    .padding(theme.spacing.xs)
                    .background(ColorTokens.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.sheetRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ElevationTokens.sheetRadius, style: .continuous)
                            .stroke(ColorTokens.cardStroke)
                    )
                    .shadow(color: ElevationTokens.shadowMedium, radius: 10, y: 5)

                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
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
        .animation(.easeInOut(duration: 0.20), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.20), value: viewModel.isRiskLoading)
        .animation(.easeInOut(duration: 0.20), value: viewModel.routeRisk?.score ?? -1)
        .tint(ColorTokens.neutralAccent)
        .background(ColorTokens.appBackground)
    }

    private func nearbyLabel(for event: GeoEvent) -> String {
        let center = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        let point = CLLocation(latitude: event.latitude, longitude: event.longitude)
        let km = center.distance(from: point) / 1000
        if km < 1 {
            return "Within 1 km"
        }
        return String(format: "%.1f km away", km)
    }
}
