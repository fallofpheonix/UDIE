//
//  APIClient.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import Foundation

final class APIClient {

    static let shared = APIClient()

    private init() {}

    private let baseURL = URL(string: "http://172.20.10.9:3000")!

    func fetchEvents(
        minLat: Double,
        maxLat: Double,
        minLng: Double,
        maxLng: Double
    ) async throws -> [GeoEvent] {

        var components = URLComponents(
            url: baseURL.appendingPathComponent("events"),
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

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([GeoEvent].self, from: data)
    }
}
