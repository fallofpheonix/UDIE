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

struct MapOperationsView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locationManager: LocationManager
    @State private var showFilters = false
    @State private var showDashboard = false
    @State private var showHealth = false
    @State private var showCommandPalette = false

    enum ActiveSheet {
        case routePlanner
        case eventDetail(GeoEvent)
    }

    @State private var activeSheet: ActiveSheet?
    @StateObject private var viewModel = MapViewModel()
    private let gridService = RiskGridService.shared

    @State private var routes: [MKRoute] = []
    @State private var selectedRoute: MKRoute?

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090), // Fallback to Delhi
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var hasCentredOnUser = false

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
        AnyView(
            ZStack(alignment: .topLeading) {
            MapSurfaceView(
                region: $region,
                events: uiState.annotations,
                snapshots: viewModel.snapshots,
                routes: uiState.routePolyline,
                selectedRoute: selectedRoute,
                onSelect: { event in
                    activeSheet = .eventDetail(event)
                }
            )

            topIntelligenceBar

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
                    state: viewModel.backendSyncState,
                    eventCount: filteredEvents.count,
                    lastUpdated: lastUpdatedText
                )
                .transition(.opacity.combined(with: .move(edge: .top)))

                if viewModel.isRiskLoading {
                    HStack {
                        ProgressView()
                        Text("Analysing risk vector...")
                            .font(Typography.caption)
                    }
                    .padding(8)
                    .background(ColorTokens.adaptiveSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(ColorTokens.cardStroke))
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

                analysisWorkbench
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, theme.spacing.md)
            .padding(.top, 60) // Space for Top Bar
            .onReceive(viewModel.$userLocation) { location in
                if let location = location, !hasCentredOnUser {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        region.center = location
                        hasCentredOnUser = true
                    }
                }
            }
            
            if showCommandPalette {
                CommandPalette(isPresented: $showCommandPalette)
            }

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
        )
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
        .fullScreenCover(isPresented: $showDashboard) {
            CityDashboardView()
        }
        .fullScreenCover(isPresented: $showHealth) {
            SystemHealthView()
        }
        .sheet(item: Binding(
            get: { viewModel.selectedH3Index.map { IdentifiableString(id: $0) } },
            set: { val in viewModel.selectedH3Index = val?.id }
        )) { item in
            if let coord = viewModel.selectedCoordinate {
                DisruptionInspectorView(h3Index: item.id, coordinate: coord)
                    .presentationDetents([.medium])
            }
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

    private var topIntelligenceBar: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "globe.asia.australia.fill")
                                .foregroundStyle(ColorTokens.accent)
                            VStack(alignment: .leading, spacing: 0) {
                                Text("REGION: DYNAMIC")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(ColorTokens.textSecondary)
                                Text(hasCentredOnUser ? "Nearby Intelligence" : "Locating...")
                                    .font(Typography.bodySmall.bold())
                            }
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ColorTokens.surfacePrimary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(ColorTokens.cardStroke))

                        Button(action: {}) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(ColorTokens.accent)
                                .clipShape(Circle())
                        }

                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(ColorTokens.textSecondary)
                            TextField("Search Intelligence...", text: .constant(""))
                                .font(Typography.bodySmall)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(ColorTokens.surfacePrimary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(ColorTokens.cardStroke))

                        Button(action: { showFilters = true }) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(ColorTokens.textPrimary)
                                .padding(10)
                                .background(ColorTokens.surfacePrimary)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(ColorTokens.cardStroke))
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(ColorTokens.accent)
                        Text("Investigation Trail:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ColorTokens.textSecondary)
                        Text(hasCentredOnUser ? "Current Location" : "Delhi")
                            .font(.system(size: 10))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                        Text("South Cluster")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ColorTokens.accent)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(ColorTokens.adaptiveSurface.opacity(0.8))
                    .clipShape(Capsule())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    IntelligenceAlertCard(title: "SPIKE: Sector 4", subtitle: "Risk index +40%", color: ColorTokens.highRisk)
                    IntelligenceAlertCard(title: "FORECAST: Flooding", subtitle: "ETA 14:30", color: ColorTokens.mediumRisk)
                }
                .frame(width: 180)
            }
            .padding(.horizontal)
            .padding(.top, 10)

            Spacer()
        }
        .allowsHitTesting(true)
    }

    private var analysisWorkbench: some View {
        HStack(alignment: .bottom) {
            VStack(spacing: 12) {
                FloatingButton(systemName: "command") {
                    showCommandPalette = true
                }
                .help("Cmd+K Search")

                FloatingButton(systemName: "layers.3.fill") {
                    showFilters = true
                }
            }
            .padding(8)
            .background(ColorTokens.adaptiveSurface.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ColorTokens.cardStroke))

            Spacer()

            TimelineSlider(value: $viewModel.temporalValue) { editing in
                if !editing {
                    viewModel.fetchSnapshots(for: region)
                }
            }
            .frame(width: 200)
            .padding(8)
            .background(ColorTokens.adaptiveSurface.opacity(0.9))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(ColorTokens.cardStroke))

            Spacer()

            VStack(spacing: 12) {
                FloatingButton(systemName: "arrow.triangle.turn.up.right.diamond.fill") {
                    activeSheet = .routePlanner
                }
                FloatingButton(systemName: viewModel.isExpertMode ? "grid.circle.fill" : "circle.hexagongrid.fill") {
                    viewModel.isExpertMode.toggle()
                }
            }
            .padding(8)
            .background(ColorTokens.adaptiveSurface.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ColorTokens.cardStroke))
        }
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

struct IdentifiableString: Identifiable {
    let id: String
}
struct IntelligenceAlertCard: View {
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(color)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            Spacer()
        }
        .padding(8)
        .background(ColorTokens.adaptiveSurface.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ColorTokens.cardStroke))
    }
}
