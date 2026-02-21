import SwiftUI
import MapKit

struct MapSurfaceView: View {
    @Binding var region: MKCoordinateRegion
    let events: [GeoEvent]
    let routes: [MKRoute]
    let selectedRoute: MKRoute?
    let onSelect: (GeoEvent) -> Void

    var body: some View {
        ClusteredMapView(
            region: $region,
            events: events,
            routes: routes,
            selectedRoute: selectedRoute,
            onSelect: onSelect
        )
        .ignoresSafeArea()
    }
}
