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
    var snapshots: [RiskSnapshotDTO]
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
            let camera = MKMapCamera(
                lookingAtCenter: region.center,
                fromDistance: mapView.camera.centerCoordinateDistance,
                pitch: mapView.camera.pitch,
                heading: mapView.camera.heading
            )
            mapView.setCamera(camera, animated: true)
        }

        let eventSignatures = Set(
            events.map { event in
                "\(event.id.uuidString)|\(event.eventType.rawValue)|\(event.severity)|\(event.confidence)|\(event.latitude)|\(event.longitude)"
            }
        )
        let routeOverlays = routes.map(\.polyline)

        if context.coordinator.lastEventSignatures != eventSignatures {
            mapView.removeAnnotations(mapView.annotations)

            let annotations = events.map { event -> EventAnnotation in
                EventAnnotation(event: event)
            }
            mapView.addAnnotations(annotations)
            context.coordinator.lastEventSignatures = eventSignatures
        }

        let currentRoutes = Set(mapView.overlays.compactMap { $0 as? MKPolyline }.map(ObjectIdentifier.init))
        let nextRoutes = Set(routeOverlays.map(ObjectIdentifier.init))
        if currentRoutes != nextRoutes {
            let activePolylines = mapView.overlays.filter { $0 is MKPolyline }
            mapView.removeOverlays(activePolylines)
            mapView.addOverlays(routeOverlays)
        }

        let snapshotIndices = Set(snapshots.map { "\($0.h3Index)|\($0.riskWeight)" })
        if context.coordinator.lastSnapshotIndices != snapshotIndices {
            let activePolygons = mapView.overlays.filter { $0 is MKPolygon }
            mapView.removeOverlays(activePolygons)

            let polygons = snapshots.compactMap { snapshot -> MKPolygon? in
                let vertices: [CLLocationCoordinate2D]
                if let boundary = snapshot.boundary, !boundary.isEmpty {
                    vertices = boundary.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
                } else if let fallback = H3CoordinateHelper.getVertices(for: snapshot.h3Index) {
                    vertices = fallback
                } else {
                    return nil
                }
                let polygon = MKPolygon(coordinates: vertices, count: vertices.count)
                polygon.title = "risk_cell|\(snapshot.riskWeight)"
                return polygon
            }
            mapView.addOverlays(polygons)
            context.coordinator.lastSnapshotIndices = snapshotIndices
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {

        var parent: ClusteredMapView

        init(_ parent: ClusteredMapView) {
            self.parent = parent
        }

        var lastEventSignatures: Set<String> = []
        var lastSnapshotIndices: Set<String> = []

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
            if let polyline = overlay as? MKPolyline {
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
            } else if let polygon = overlay as? MKPolygon {
                let weight = Double(polygon.title?.split(separator: "|").last ?? "0") ?? 0
                let renderer = SoftGlowPolygonRenderer(polygon: polygon)
                let color = colorForWeight(weight)
                renderer.fillColor = color.withAlphaComponent(0.35)
                renderer.strokeColor = color.withAlphaComponent(0.6)
                renderer.lineWidth = 1.5
                renderer.glowColor = color
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        private func colorForWeight(_ weight: Double) -> UIColor {
            if weight > 8 { return UIColor(ColorTokens.highRisk) }
            if weight > 4 { return UIColor(ColorTokens.mediumRisk) }
            return UIColor(ColorTokens.lowRisk)
        }

        func mapView(_ mapView: MKMapView,
                     didSelect view: MKAnnotationView) {

            // Tap glow feedback
            UIView.animate(withDuration: 0.12, delay: 0, options: .curveEaseOut, animations: {
                view.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
                view.layer.shadowColor = (view as? MKMarkerAnnotationView)?.markerTintColor?.cgColor
                view.layer.shadowOpacity = 0.8
                view.layer.shadowRadius = 10
            }, completion: { _ in
                UIView.animate(withDuration: 0.12) {
                    view.transform = .identity
                    view.layer.shadowOpacity = 0.3
                }
            })

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
