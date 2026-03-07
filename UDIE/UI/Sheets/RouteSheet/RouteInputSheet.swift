import SwiftUI
import Combine
import MapKit

struct RouteInputSheet: View {
    @Binding var region: MKCoordinateRegion
    @Binding var routes: [MKRoute]
    @Binding var selectedRoute: MKRoute?
    let onRouteRequested: () -> Void

    var body: some View {
        RoutePlannerView(
            region: $region,
            routes: $routes,
            selectedRoute: $selectedRoute,
            onRouteReady: onRouteRequested
        )
    }
}
