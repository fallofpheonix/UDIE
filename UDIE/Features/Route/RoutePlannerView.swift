//
//  RoutePlannerView.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import SwiftUI
import MapKit

struct RoutePlannerView: View {

    @Binding var region: MKCoordinateRegion
    @Binding var routes: [MKRoute]
    @Binding var selectedRoute: MKRoute?
    var onRouteReady: (() -> Void)? = nil

    @State private var originText = ""
    @State private var destinationText = ""
    @State private var isLoading = false
    @State private var statusMessage: String?
    @State private var isErrorStatus = false
    @State private var routeSummary: RouteSummary?
    @FocusState private var focusedField: Field?

    private enum Field {
        case origin
        case destination
    }

    private struct DemoRoutePreset: Identifiable {
        let id = UUID()
        let title: String
        let origin: String
        let destination: String
    }

    private struct RouteSummary {
        let etaText: String
        let distanceText: String
        let arrivalText: String
    }

    private let demoPresets: [DemoRoutePreset] = [
        .init(title: "CP -> India Gate", origin: "Connaught Place, New Delhi", destination: "India Gate, New Delhi"),
        .init(title: "Rajiv Chowk -> Khan Market", origin: "Rajiv Chowk Metro Station, New Delhi", destination: "Khan Market, New Delhi"),
        .init(title: "NDLS -> AIIMS", origin: "New Delhi Railway Station", destination: "AIIMS Delhi")
    ]

    var body: some View {
        VStack(spacing: SpacingScale.md) {
            header
            inputCard
            presetsRow

            if let routeSummary {
                routeReadyCard(summary: routeSummary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(isErrorStatus ? ColorTokens.highRisk : ColorTokens.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SpacingScale.xs)
            }

            Spacer(minLength: SpacingScale.sm)

            actionButton
        }
        .padding(.horizontal, SpacingScale.md)
        .padding(.top, SpacingScale.md)
        .padding(.bottom, SpacingScale.lg)
        .background(ColorTokens.appBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingScale.xs2) {
            Text("Plan a risk-aware route")
                .font(.headline)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("Find a route and let UDIE overlay live disruption risk.")
                .font(.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputCard: some View {
        VStack(spacing: SpacingScale.sm) {
            inputField(
                title: "Origin",
                placeholder: "Enter pickup location",
                text: $originText,
                field: .origin,
                submitLabel: .next
            ) {
                focusedField = .destination
            }

            inputField(
                title: "Destination",
                placeholder: "Enter destination",
                text: $destinationText,
                field: .destination,
                submitLabel: .done
            ) {
                focusedField = nil
                calculateRoute()
            }
        }
        .padding(SpacingScale.md)
        .background(ColorTokens.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.sheetRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ElevationTokens.sheetRadius, style: .continuous)
                .stroke(ColorTokens.cardStroke)
        )
        .shadow(color: ElevationTokens.shadowSoft, radius: 8, y: 4)
    }

    private var presetsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingScale.xs) {
                ForEach(demoPresets) { preset in
                    Button(preset.title) {
                        originText = preset.origin
                        destinationText = preset.destination
                        statusMessage = "Preset loaded. Tap Analyze Route."
                        isErrorStatus = false
                        routeSummary = nil
                        focusedField = nil
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .padding(.horizontal, SpacingScale.sm)
                    .padding(.vertical, SpacingScale.xs)
                    .background(ColorTokens.chipBackground)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(ColorTokens.cardStroke)
                    )
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
    }

    private var actionButton: some View {
        Button {
            calculateRoute()
        } label: {
            HStack(spacing: SpacingScale.xs) {
                if isLoading {
                    ProgressView()
                        .tint(ColorTokens.surfacePrimary)
                }
                Text(isLoading ? "Analyzing" : "Analyze Route")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(ColorTokens.surfacePrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingScale.sm)
            .background(ColorTokens.neutralPrimary)
            .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.pillRadius, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1)
    }

    private func routeReadyCard(summary: RouteSummary) -> some View {
        VStack(alignment: .leading, spacing: SpacingScale.xs) {
            Text("Route Ready")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(ColorTokens.neutralPrimary)

            HStack {
                routeStat(summary.etaText, icon: "clock")
                Spacer()
                routeStat(summary.distanceText, icon: "map")
                Spacer()
                routeStat(summary.arrivalText, icon: "calendar")
            }
        }
        .padding(SpacingScale.md)
        .background(ColorTokens.surfaceTintedA)
        .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ElevationTokens.cardRadius, style: .continuous)
                .stroke(ColorTokens.cardStroke)
        )
    }

    private func routeStat(_ value: String, icon: String) -> some View {
        HStack(spacing: SpacingScale.xxs) {
            Image(systemName: icon)
            Text(value)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(ColorTokens.textSecondary)
    }

    private func inputField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        submitLabel: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingScale.xxs) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ColorTokens.textSecondary)

            TextField(placeholder, text: text)
                .focused($focusedField, equals: field)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
                .padding(.horizontal, SpacingScale.sm)
                .padding(.vertical, SpacingScale.sm)
                .background(ColorTokens.surfaceSecondary)
                .foregroundStyle(ColorTokens.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: ElevationTokens.pillRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ElevationTokens.pillRadius, style: .continuous)
                        .stroke(ColorTokens.cardStroke)
                )
        }
    }

    private func calculateRoute() {
        focusedField = nil
        statusMessage = nil
        isErrorStatus = false
        routeSummary = nil

        guard !originText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !destinationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "Enter both origin and destination."
            isErrorStatus = true
            return
        }

        isLoading = true
        Task { @MainActor in
            do {
                let sourceItem = try await geocodeMapItem(address: originText)
                let destinationItem = try await geocodeMapItem(address: destinationText)

                let request = MKDirections.Request()
                request.source = sourceItem
                request.destination = destinationItem
                request.transportType = .automobile

                let directions = MKDirections(request: request)
                let response = try await directions.calculate()

                isLoading = false

                if let first = response.routes.first {
                    routes = response.routes
                    selectedRoute = first
                    region = MKCoordinateRegion(first.polyline.boundingMapRect)
                    statusMessage = "Route ready. Showing risk overlays on map."
                    isErrorStatus = false
                    routeSummary = makeRouteSummary(from: first)
                    onRouteReady?()
                } else {
                    statusMessage = "No drivable route found."
                    isErrorStatus = true
                }
            } catch {
                isLoading = false
                statusMessage = "Route calculation failed: \(error.localizedDescription)"
                isErrorStatus = true
            }
        }
    }

    private func geocodeMapItem(address: String) async throws -> MKMapItem {
        if #available(iOS 26.0, *) {
            guard let request = MKGeocodingRequest(addressString: address) else {
                throw NSError(domain: "UDIE.RoutePlanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid address: \(address)"])
            }
            let items = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[MKMapItem], Error>) in
                request.getMapItems(completionHandler: { mapItems, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: mapItems ?? [])
                })
            }
            guard let item = items.first else {
                throw NSError(domain: "UDIE.RoutePlanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "No result for \(address)"])
            }
            return item
        }

        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = address
        let search = MKLocalSearch(request: searchRequest)
        let response = try await search.start()
        guard let item = response.mapItems.first else {
            throw NSError(domain: "UDIE.RoutePlanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "No result for \(address)"])
        }
        return item
    }

    private func makeRouteSummary(from route: MKRoute) -> RouteSummary {
        let eta = max(1, Int((route.expectedTravelTime / 60).rounded()))
        let distance = String(format: "%.1f km", route.distance / 1000)
        let arrivalDate = Date().addingTimeInterval(route.expectedTravelTime)

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        return RouteSummary(
            etaText: "\(eta) min",
            distanceText: distance,
            arrivalText: formatter.string(from: arrivalDate)
        )
    }
}
