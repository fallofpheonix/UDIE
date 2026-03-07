import SwiftUI

struct MainContainerView: View {
    @State private var selectedTab = 1
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            
            MapSurfaceView(
                region: $appState.region,
                events: appState.events,
                snapshots: appState.snapshots,
                routes: appState.routes,
                selectedRoute: appState.selectedRoute,
                onSelect: { event in
                    appState.selectedEvent = event
                }
            )
            .tabItem { Label("Map", systemImage: "map.fill") }
            .tag(1)
            
            IntelligenceFeedView()
                .tabItem { Label("Breumbs", systemImage: "signal") }
                .tag(2)
            
            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.bar.xaxis") }
                .tag(3)
            
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(ColorTokens.accent)
    }
}

