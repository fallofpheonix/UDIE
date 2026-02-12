//
//  APIClient.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import Foundation
import CoreLocation

final class APIClient {

    static let shared = APIClient()

    private init() {}

    private let baseURL: URL = {
        if let configured = ProcessInfo.processInfo.environment["UDIE_API_BASE_URL"],
           let url = URL(string: configured) {
            return url
        }
        return URL(string: "http://127.0.0.1:3000")!
    }()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    func fetchEvents(
        minLat: Double,
        maxLat: Double,
        minLng: Double,
        maxLng: Double
    ) async throws -> [GeoEvent] {

        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/events"),
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(name: "minLat", value: "\(minLat)"),
            URLQueryItem(name: "maxLat", value: "\(maxLat)"),
            URLQueryItem(name: "minLng", value: "\(minLng)"),
            URLQueryItem(name: "maxLng", value: "\(maxLng)")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([GeoEvent].self, from: data)
    }

    func fetchRouteRisk(
        coordinates: [CLLocationCoordinate2D],
        city: String
    ) async throws -> RouteRiskResponse {

        let url = baseURL.appendingPathComponent("api/risk")
        let payload = RouteRiskRequest(
            coordinates: coordinates.map {
                CoordinateDTO(lat: $0.latitude, lng: $0.longitude)
            },
            city: city
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(RouteRiskResponse.self, from: data)
    }
}
