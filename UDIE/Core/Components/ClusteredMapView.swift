//
//  ClusteredMapView.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import SwiftUI
import MapKit
import CoreLocation

struct ClusteredMapView: UIViewRepresentable {

    @Binding var region: MKCoordinateRegion
    var events: [GeoEvent]
    var onSelect: (GeoEvent) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {

        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)

        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: "Event"
        )

        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier:
                MKMapViewDefaultClusterAnnotationViewReuseIdentifier
        )

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {

        if mapView.region.center.latitude != region.center.latitude ||
           mapView.region.center.longitude != region.center.longitude {
            mapView.setRegion(region, animated: true)
        }

        mapView.removeAnnotations(mapView.annotations)

        let annotations = events.map { event -> EventAnnotation in
            EventAnnotation(event: event)
        }

        mapView.addAnnotations(annotations)
    }

    class Coordinator: NSObject, MKMapViewDelegate {

        var parent: ClusteredMapView

        init(_ parent: ClusteredMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView,
                     regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }

        func mapView(_ mapView: MKMapView,
                     viewFor annotation: MKAnnotation)
        -> MKAnnotationView? {

            if let cluster = annotation as? MKClusterAnnotation {

                let view = MKMarkerAnnotationView(
                    annotation: cluster,
                    reuseIdentifier:
                        MKMapViewDefaultClusterAnnotationViewReuseIdentifier
                )

                view.markerTintColor = .systemBlue
                view.canShowCallout = false
                return view
            }

            guard let eventAnnotation = annotation as? EventAnnotation else {
                return nil
            }

            let view = MKMarkerAnnotationView(
                annotation: eventAnnotation,
                reuseIdentifier: "Event"
            )

            view.clusteringIdentifier = "eventCluster"
            // TODO: Map EventType to a display color when available (e.g., via a computed property or extension)
            view.markerTintColor = .systemBlue
            view.canShowCallout = false

            return view
        }

        func mapView(_ mapView: MKMapView,
                     didSelect view: MKAnnotationView) {

            if let eventAnnotation = view.annotation as? EventAnnotation {
                parent.onSelect(eventAnnotation.event)
            }
        }
    }
}

final class EventAnnotation: NSObject, MKAnnotation {

    let event: GeoEvent

    var coordinate: CLLocationCoordinate2D {
        event.coordinate
    }

    init(event: GeoEvent) {
        self.event = event
    }
}
