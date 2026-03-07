import Foundation
import Combine
import MapKit

final class AppState: ObservableObject {
    @Published var filters = EventFilter()
    
    // Spatial State
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    // Data Collections
    @Published var events: [GeoEvent] = []
    @Published var snapshots: [RiskSnapshotDTO] = []
    @Published var routes: [MKRoute] = []
    
    // Selection State
    @Published var selectedRoute: MKRoute?
    @Published var selectedEvent: GeoEvent?
}
