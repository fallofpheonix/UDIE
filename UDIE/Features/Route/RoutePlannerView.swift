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

        geocoder.geocodeAddressString(originText) { originPlacemarks, _ in
            guard let origin = originPlacemarks?.first?.location else {
                DispatchQueue.main.async {
                    isLoading = false
                    statusMessage = "Could not find origin. Try a fuller address."
                    isErrorStatus = true
                }
                return
            }

            geocoder.geocodeAddressString(destinationText) { destPlacemarks, _ in
                guard let destination = destPlacemarks?.first?.location else {
                    DispatchQueue.main.async {
                        isLoading = false
                        statusMessage = "Could not find destination. Try a fuller address."
                        isErrorStatus = true
                    }
                    return
                }

                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.coordinate))
                request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
                request.transportType = .automobile

                let directions = MKDirections(request: request)

                directions.calculate { response, _ in
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
                            statusMessage = "No drivable route found."
                            isErrorStatus = true
                        }

                    }
                }
            }
        }
    }
}
