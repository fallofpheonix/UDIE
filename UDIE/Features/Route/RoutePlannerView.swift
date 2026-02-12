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

    @State private var originText = ""
    @State private var destinationText = ""
    @State private var isLoading = false

    var body: some View {

        VStack(spacing: 16) {

            TextField("Origin", text: $originText)
                .textFieldStyle(.roundedBorder)

            TextField("Destination", text: $destinationText)
                .textFieldStyle(.roundedBorder)

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

            Spacer()
        }
        .padding()
    }

    private func calculateRoute() {

        isLoading = true

        let geocoder = CLGeocoder()

        geocoder.geocodeAddressString(originText) { originPlacemarks, _ in
            guard let origin = originPlacemarks?.first?.location else {
                isLoading = false
                return
            }

            geocoder.geocodeAddressString(destinationText) { destPlacemarks, _ in
                guard let destination = destPlacemarks?.first?.location else {
                    isLoading = false
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

                        if let foundRoutes = response?.routes {
                            routes = foundRoutes
                            selectedRoute = foundRoutes.first

                            region = MKCoordinateRegion(foundRoutes.first!.polyline.boundingMapRect)
                        }
                    }
                }
            }
        }
    }
}
