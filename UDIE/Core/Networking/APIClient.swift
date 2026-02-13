//
//  APIClient.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import Foundation
import CoreLocation

enum APIClientError: LocalizedError {
    case invalidResponse(statusCode: Int, body: String)
    case connectivity(baseURL: String, underlying: URLError)

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let statusCode, let body):
            return "Server returned \(statusCode). \(body)"
        case .connectivity(let baseURL, let underlying):
            return "Cannot connect to backend at \(baseURL). \(underlying.localizedDescription)"
        }
    }
}

final class APIClient {

    static let shared = APIClient()

    private init() {}

    #if targetEnvironment(simulator)
    private static let fallbackBaseURLString = "http://127.0.0.1:3000"
    #else
    // Demo-safe default for physical device on same LAN as backend host.
    private static let fallbackBaseURLString = "http://172.25.214.59:3000"
    #endif

    private let baseURL: URL = {
        if let configured = ProcessInfo.processInfo.environment["UDIE_API_BASE_URL"],
           let url = URL(string: configured) {
            return url
        }
        if let infoURL = Bundle.main.object(forInfoDictionaryKey: "UDIE_API_BASE_URL") as? String,
           let url = URL(string: infoURL) {
            return url
        }
        return URL(string: APIClient.fallbackBaseURLString)!
    }()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    func healthCheck() async throws {
        let url = baseURL.appendingPathComponent("api/health")
        do {
            let (_, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                throw URLError(.badServerResponse)
            }
        } catch let error as URLError {
            throw APIClientError.connectivity(baseURL: baseURL.absoluteString, underlying: error)
        }
    }

    func fetchEvents(
        minLat: Double,
        maxLat: Double,
        minLng: Double,
        maxLng: Double,
        city: String = "BLR"
    ) async throws -> [GeoEvent] {

        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/events"),
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(name: "minLat", value: "\(minLat)"),
            URLQueryItem(name: "maxLat", value: "\(maxLat)"),
            URLQueryItem(name: "minLng", value: "\(minLng)"),
            URLQueryItem(name: "maxLng", value: "\(maxLng)"),
            URLQueryItem(name: "city", value: city)
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        #if DEBUG
        print("API base URL:", baseURL.absoluteString)
        #endif

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as URLError {
            throw APIClientError.connectivity(baseURL: baseURL.absoluteString, underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw APIClientError.invalidResponse(
                statusCode: httpResponse.statusCode,
                body: String(data: data, encoding: .utf8) ?? "No response body"
            )
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

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIClientError.connectivity(baseURL: baseURL.absoluteString, underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw APIClientError.invalidResponse(
                statusCode: httpResponse.statusCode,
                body: String(data: data, encoding: .utf8) ?? "No response body"
            )
        }

        return try JSONDecoder().decode(RouteRiskResponse.self, from: data)
    }
}
