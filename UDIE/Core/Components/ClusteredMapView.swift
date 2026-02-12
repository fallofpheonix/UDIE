//
//  ClusteredMapView.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import SwiftUI
import MapKit

struct ClusteredMapView: UIViewRepresentable {

    var region: MKCoordinateRegion
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
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier
        )

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {

        mapView.setRegion(region, animated: true)

        mapView.removeAnnotations(mapView.annotations)

        let annotations = events.map { event -> MKPointAnnotation in
            let annotation = MKPointAnnotation()
            annotation.coordinate = event.coordinate
            annotation.title = event.eventType.displayName
            return annotation
        }

        mapView.addAnnotations(annotations)
    }

    class Coordinator: NSObject, MKMapViewDelegate {

        var parent: ClusteredMapView

        init(_ parent: ClusteredMapView) {
            self.parent = parent
        }

        func mapView(
            _ mapView: MKMapView,
            viewFor annotation: MKAnnotation
        ) -> MKAnnotationView? {

            if annotation is MKClusterAnnotation {
                let view = MKMarkerAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier
                )
                view.markerTintColor = .systemBlue
                view.canShowCallout = false
                return view
            }

            let view = MKMarkerAnnotationView(
                annotation: annotation,
                reuseIdentifier: "Event"
            )

            view.clusteringIdentifier = "eventCluster"
            view.canShowCallout = false

            return view
        }
    }
}
