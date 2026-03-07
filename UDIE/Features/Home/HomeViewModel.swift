import Foundation
import Combine
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var dashboardData: CityDashboardResponse?
    @Published var recentEvents: [GeoEvent] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // cityCode defaults to "DEL" as per MapViewModel pattern
    var cityCode = "DEL"
    
    private let repository = EventRepository()
    
    func refreshData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let dashboard = APIClient.shared.fetchCityDashboard(
                minLat: 28.5,
                maxLat: 28.7,
                minLng: 77.1,
                maxLng: 77.3
            )
            // Fetching a small subset of events for the home feed
            async let events = repository.getEvents(
                minLat: 28.5, maxLat: 28.7, // Delhi region approximate
                minLng: 77.1, maxLng: 77.3,
                city: cityCode
            )
            
            let (fetchedDashboard, fetchedEvents) = try await (dashboard, events)
            
            self.dashboardData = fetchedDashboard
            self.recentEvents = Array(fetchedEvents.prefix(5))
        } catch {
            errorMessage = "Failed to sync home intelligence"
            print("Home Sync Error: \(error)")
        }
        
        isLoading = false
    }
}
