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

    private static let fallbackBaseURLString = "http://127.0.0.1:3000"
    private let maxRetries = 2
    private let retryDelayNanos: UInt64 = 250_000_000

    private let baseURL: URL = {
        let env = ProcessInfo.processInfo.environment
        // Accept both names to avoid config mismatch during scheme setup.
        let envKeys = ["UDIE_API_BASE_URL", "INFOPLIST_KEY_UDIE_API_BASE_URL"]
        for key in envKeys {
            if let configured = env[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !configured.isEmpty,
               let url = URL(string: configured) {
                return url
            }
        }
        if let infoURL = Bundle.main.object(forInfoDictionaryKey: "UDIE_API_BASE_URL") as? String {
            let configured = infoURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !configured.isEmpty, let url = URL(string: configured) {
                return url
            }
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
            let (_, response) = try await performDataRequest(url: url)
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
        city: String
    ) async throws -> [GeoEvent] {

        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/events"),
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(name: "minLat", value: String(format: "%.6f", minLat)),
            URLQueryItem(name: "maxLat", value: String(format: "%.6f", maxLat)),
            URLQueryItem(name: "minLng", value: String(format: "%.6f", minLng)),
            URLQueryItem(name: "maxLng", value: String(format: "%.6f", maxLng)),
            URLQueryItem(name: "city", value: city)
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        #if DEBUG
        print("🚀 API Request [GET]: \(url.absoluteString)")
        #endif

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await performDataRequest(url: url)
        } catch let error as URLError {
            #if DEBUG
            print("❌ API Error [GET]: \(error.localizedDescription) at \(baseURL.absoluteString)")
            #endif
            throw APIClientError.connectivity(baseURL: baseURL.absoluteString, underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        #if DEBUG
        print("✅ API Response [GET]: \(httpResponse.statusCode)")
        #endif

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

        #if DEBUG
        print("🚀 API Request [POST]: \(url.absoluteString) | Body size: \(request.httpBody?.count ?? 0) bytes")
        #endif

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await performDataRequest(request: request)
        } catch let error as URLError {
            #if DEBUG
            print("❌ API Error [POST]: \(error.localizedDescription) at \(baseURL.absoluteString)")
            #endif
            throw APIClientError.connectivity(baseURL: baseURL.absoluteString, underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        #if DEBUG
        print("✅ API Response [POST]: \(httpResponse.statusCode)")
        #endif

        guard 200..<300 ~= httpResponse.statusCode else {
            throw APIClientError.invalidResponse(
                statusCode: httpResponse.statusCode,
                body: String(data: data, encoding: .utf8) ?? "No response body"
            )
        }

        return try JSONDecoder().decode(RouteRiskResponse.self, from: data)
    }

    private func performDataRequest(url: URL) async throws -> (Data, URLResponse) {
        var attempt = 0
        while true {
            try Task.checkCancellation()
            do {
                return try await session.data(from: url)
            } catch let error as URLError {
                if attempt >= maxRetries || !isRetriable(error: error) {
                    throw error
                }
                attempt += 1
                try await Task.sleep(nanoseconds: retryDelayNanos * UInt64(attempt))
            }
        }
    }

    private func performDataRequest(request: URLRequest) async throws -> (Data, URLResponse) {
        var attempt = 0
        while true {
            try Task.checkCancellation()
            do {
                return try await session.data(for: request)
            } catch let error as URLError {
                if attempt >= maxRetries || !isRetriable(error: error) {
                    throw error
                }
                attempt += 1
                try await Task.sleep(nanoseconds: retryDelayNanos * UInt64(attempt))
            }
        }
    }

    private func isRetriable(error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }
}
