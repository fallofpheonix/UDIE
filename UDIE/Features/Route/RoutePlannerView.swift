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

    private let demoPresets: [DemoRoutePreset] = [
        .init(title: "CP -> India Gate", origin: "Connaught Place, New Delhi", destination: "India Gate, New Delhi"),
        .init(title: "Rajiv Chowk -> Khan Market", origin: "Rajiv Chowk Metro Station, New Delhi", destination: "Khan Market, New Delhi"),
        .init(title: "NDLS -> AIIMS", origin: "New Delhi Railway Station", destination: "AIIMS Delhi")
    ]

    var body: some View {

        ScrollView {
            VStack(spacing: 16) {

                TextField("Origin", text: $originText)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .origin)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .destination
                    }

                TextField("Destination", text: $destinationText)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .destination)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                        calculateRoute()
                    }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(demoPresets) { preset in
                            Button(preset.title) {
                                originText = preset.origin
                                destinationText = preset.destination
                                statusMessage = "Preset loaded. Tap Calculate Route."
                                isErrorStatus = false
                                focusedField = nil
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                Button {
                    calculateRoute()
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Calculate Route")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(isErrorStatus ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 8)
            }
            .padding()
        }
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

    private func calculateRoute() {
        focusedField = nil
        statusMessage = nil
        isErrorStatus = false

        guard !originText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !destinationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "Enter both origin and destination."
            isErrorStatus = true
            return
        }

        isLoading = true

        let geocoder = CLGeocoder()

        geocoder.geocodeAddressString(originText) { originPlacemarks, error in
            guard let origin = originPlacemarks?.first?.location else {
                DispatchQueue.main.async {
                    isLoading = false
                    if let error {
                        statusMessage = "Origin lookup failed: \(error.localizedDescription)"
                    } else {
                        statusMessage = "Could not find origin. Try a fuller address."
                    }
                    isErrorStatus = true
                }
                return
            }

            geocoder.geocodeAddressString(destinationText) { destPlacemarks, error in
                guard let destination = destPlacemarks?.first?.location else {
                    DispatchQueue.main.async {
                        isLoading = false
                        if let error {
                            statusMessage = "Destination lookup failed: \(error.localizedDescription)"
                        } else {
                            statusMessage = "Could not find destination. Try a fuller address."
                        }
                        isErrorStatus = true
                    }
                    return
                }

                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.coordinate))
                request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
                request.transportType = .automobile

                let directions = MKDirections(request: request)

                directions.calculate { response, error in
                    DispatchQueue.main.async {

                        isLoading = false

                        if let foundRoutes = response?.routes,
                           let first = foundRoutes.first {

                            routes = foundRoutes
                            selectedRoute = first
                            region = MKCoordinateRegion(first.polyline.boundingMapRect)
                            statusMessage = "Route ready. Showing on map."
                            isErrorStatus = false
                            onRouteReady?()
                        } else {
                            if let error {
                                statusMessage = "Route calculation failed: \(error.localizedDescription)"
                            } else {
                                statusMessage = "No drivable route found."
                            }
                            isErrorStatus = true
                        }

                    }
                }
            }
        }
    }
}
