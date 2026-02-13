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
    var routes: [MKRoute]
    var selectedRoute: MKRoute?
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

        let latDelta = abs(mapView.region.center.latitude - region.center.latitude)
        let lngDelta = abs(mapView.region.center.longitude - region.center.longitude)
        if latDelta > 0.0001 || lngDelta > 0.0001 {
            mapView.setRegion(region, animated: true)
        }

        let eventIDs = Set(events.map(\.id))
        let routeOverlays = routes.map(\.polyline)

        if context.coordinator.lastEventIDs != eventIDs {
            mapView.removeAnnotations(mapView.annotations)

            let annotations = events.map { event -> EventAnnotation in
                EventAnnotation(event: event)
            }
            mapView.addAnnotations(annotations)
            context.coordinator.lastEventIDs = eventIDs
        }

        let currentRoutes = Set(mapView.overlays.compactMap { $0 as? MKPolyline }.map(ObjectIdentifier.init))
        let nextRoutes = Set(routeOverlays.map(ObjectIdentifier.init))
        if currentRoutes != nextRoutes {
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlays(routeOverlays)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {

        var parent: ClusteredMapView

        init(_ parent: ClusteredMapView) {
            self.parent = parent
        }

        var lastEventIDs: Set<UUID> = []

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
            view.markerTintColor = UIColor(eventAnnotation.event.eventType.displayColor)
            view.canShowCallout = false
            view.layer.removeAnimation(forKey: "severityPulse")

            if eventAnnotation.event.severity >= 4 {
                let pulse = CABasicAnimation(keyPath: "transform.scale")
                pulse.fromValue = 1.0
                pulse.toValue = 1.12
                pulse.duration = 0.8
                pulse.autoreverses = true
                pulse.repeatCount = .infinity
                pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                view.layer.add(pulse, forKey: "severityPulse")
            }

            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = ShadowPolylineRenderer(polyline: polyline)

            let isSelectedRoute = parent.selectedRoute?.polyline === polyline
            renderer.strokeColor = isSelectedRoute
                ? UIColor.systemBlue
                : UIColor.systemBlue.withAlphaComponent(0.35)
            renderer.lineWidth = isSelectedRoute ? 6 : 4
            renderer.shadowColor = .black
            renderer.shadowOffset = CGSize(width: 0, height: 2)
            renderer.shadowOpacity = 0.3

            return renderer
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

final class ShadowPolylineRenderer: MKPolylineRenderer {
    var shadowColor: UIColor = .clear
    var shadowOffset: CGSize = .zero
    var shadowOpacity: CGFloat = 0

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        context.saveGState()
        context.setShadow(
            offset: shadowOffset,
            blur: 4,
            color: shadowColor.withAlphaComponent(shadowOpacity).cgColor
        )
        super.draw(mapRect, zoomScale: zoomScale, in: context)
        context.restoreGState()
    }
}
