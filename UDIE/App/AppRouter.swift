import SwiftUI
import MapKit

struct AppRouter: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var plannerRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
    @State private var plannerRoutes: [MKRoute] = []
    @State private var plannerSelectedRoute: MKRoute?

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Awareness", systemImage: "house.fill")
                }

            MapOperationsView()
                .tabItem {
                    Label("Investigate", systemImage: "map.fill")
                }

            RoutePlannerView(
                region: $plannerRegion,
                routes: $plannerRoutes,
                selectedRoute: $plannerSelectedRoute
            )
                .tabItem {
                    Label("Decision", systemImage: "arrow.triangle.swap")
                }

            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView()
                .tabItem {
                    Label("System", systemImage: "cpu")
                }
        }
    }
}
