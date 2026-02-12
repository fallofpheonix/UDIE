final class APIClient {

    static let shared = APIClient()

    private init() { }

    func fetchEvents() async -> [GeoEvent] {
        return []
    }
}
