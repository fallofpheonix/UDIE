import Foundation
import MapKit

struct MapUIState {
    let region: MKCoordinateRegion
    let annotations: [GeoEvent]
    let routePolyline: [MKRoute]
    let riskLevel: RiskLevel?
    let isLoading: Bool
}
