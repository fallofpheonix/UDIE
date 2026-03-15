//  APIClient.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//
//  Role: Authoritative networking layer for the UDIE substrate.
//  Enforces bounded-cost API contracts and provides robust retry logic.
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

    private static let fallbackBaseURLString = "http://localhost:3000"
    private static let primaryAPIPrefix = "api/v1"
    private static let legacyAPIPrefix = "api"
    private let maxRetries = 2
    private let retryDelayNanos: UInt64 = 250_000_000
    private var resolvedAPIPrefix: String?

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
        if let fallbackURL = URL(string: APIClient.fallbackBaseURLString) {
            return fallbackURL
        }
        fatalError("Invalid fallback URL configuration.")
    }()

    private static var hasWarnedDeviceLocalhost = false
    private func warnIfDeviceUsingLocalhost() {
        #if DEBUG
        guard !Self.hasWarnedDeviceLocalhost,
              baseURL.host.map({ $0 == "localhost" || $0 == "127.0.0.1" }) == true else { return }
        #if targetEnvironment(simulator)
        // Simulator can reach host's localhost; no warning.
        #else
        Self.hasWarnedDeviceLocalhost = true
        print("⚠️ UDIE: Backend URL is \(baseURL.absoluteString). On a physical device this usually fails. Set UDIE_API_BASE_URL to your Mac's IP (e.g. http://192.168.1.x:3000) in Scheme → Run → Environment Variables, then clean and rebuild.")
        #endif
        #endif
    }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private struct WebSocketEnvelope<Payload: Codable>: Codable {
        let event: String
        let data: Payload
    }

    private struct RiskSurfaceSubscriptionRequest: Codable {
        let minLat: Double
        let maxLat: Double
        let minLng: Double
        let maxLng: Double
        let limit: Int
    }

    private struct RiskSurfaceStreamEnvelope: Decodable {
        let event: String
        let data: RiskSurfaceStreamPayload?
    }

    struct RiskSurfaceStreamPayload: Decodable {
        let updatedAt: String
        let cellCount: Int
        let cells: [RiskSnapshotDTO]
    }

    func getBaseURL() -> String {
        warnIfDeviceUsingLocalhost()
        return baseURL.absoluteString
    }

    func healthCheck() async throws {
        warnIfDeviceUsingLocalhost()
        let prefix = try await resolveAPIPrefix()
        let url = baseURL.appendingPathComponent(prefix).appendingPathComponent("health")
        do {
            let (data, response) = try await performDataRequest(url: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if !(200..<300 ~= httpResponse.statusCode) {
                let body = String(data: data, encoding: .utf8) ?? "No response body"
                throw APIClientError.invalidResponse(statusCode: httpResponse.statusCode, body: body)
            }
        } catch let error as APIClientError {
            throw error
        } catch let error as URLError {
            throw APIClientError.connectivity(baseURL: baseURL.absoluteString, underlying: error)
        } catch {
            throw error
        }
    }

    func fetchEvents(
        minLat: Double,
        maxLat: Double,
        minLng: Double,
        maxLng: Double,
        city: String
    ) async throws -> [GeoEvent] {

        let prefix = try await resolveAPIPrefix()
        var components = URLComponents(
            url: baseURL.appendingPathComponent(prefix).appendingPathComponent("events"),
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

        let prefix = try await resolveAPIPrefix()
        let url = baseURL.appendingPathComponent(prefix).appendingPathComponent("risk")
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

    func fetchCityDashboard(
        minLat: Double,
        maxLat: Double,
        minLng: Double,
        maxLng: Double,
        hotspotThreshold: Double? = nil
    ) async throws -> CityDashboardResponse {
        let prefix = try await resolveAPIPrefix()
        var components = URLComponents(
            url: baseURL.appendingPathComponent(prefix).appendingPathComponent("city-dashboard"),
            resolvingAgainstBaseURL: false
        )
        
        var queryItems = [
            URLQueryItem(name: "minLat", value: String(format: "%.6f", minLat)),
            URLQueryItem(name: "maxLat", value: String(format: "%.6f", maxLat)),
            URLQueryItem(name: "minLng", value: String(format: "%.6f", minLng)),
            URLQueryItem(name: "maxLng", value: String(format: "%.6f", maxLng))
        ]
        
        if let threshold = hotspotThreshold {
            queryItems.append(URLQueryItem(name: "hotspotThreshold", value: String(format: "%.2f", threshold)))
        }
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else { throw URLError(.badURL) }
        
        let (data, response) = try await performDataRequest(url: url)
        try validateResponse(response, data: data)
        
        return try JSONDecoder().decode(CityDashboardResponse.self, from: data)
    }

    func fetchCellInsight(lat: Double, lng: Double) async throws -> CellInsightResponse {
        let prefix = try await resolveAPIPrefix()
        var components = URLComponents(
            url: baseURL.appendingPathComponent(prefix).appendingPathComponent("cell-insight"),
            resolvingAgainstBaseURL: false
        )
        
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.6f", lat)),
            URLQueryItem(name: "lng", value: String(format: "%.6f", lng))
        ]
        
        guard let url = components?.url else { throw URLError(.badURL) }
        
        let (data, response) = try await performDataRequest(url: url)
        try validateResponse(response, data: data)
        
        return try JSONDecoder().decode(CellInsightResponse.self, from: data)
    }

    func fetchRiskSnapshots(
        start: Date,
        end: Date,
        minLat: Double,
        maxLat: Double,
        minLng: Double,
        maxLng: Double,
        limit: Int = 10000
    ) async throws -> RiskSnapshotsResponse {
        let prefix = try await resolveAPIPrefix()
        var components = URLComponents(
            url: baseURL.appendingPathComponent(prefix).appendingPathComponent("risk-snapshots"),
            resolvingAgainstBaseURL: false
        )
        
        let formatter = ISO8601DateFormatter()
        
        components?.queryItems = [
            URLQueryItem(name: "start_time", value: formatter.string(from: start)),
            URLQueryItem(name: "end_time", value: formatter.string(from: end)),
            URLQueryItem(name: "minLat", value: String(format: "%.6f", minLat)),
            URLQueryItem(name: "maxLat", value: String(format: "%.6f", maxLat)),
            URLQueryItem(name: "minLng", value: String(format: "%.6f", minLng)),
            URLQueryItem(name: "maxLng", value: String(format: "%.6f", maxLng)),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        guard let url = components?.url else { throw URLError(.badURL) }
        
        let (data, response) = try await performDataRequest(url: url)
        try validateResponse(response, data: data)
        
        return try JSONDecoder().decode(RiskSnapshotsResponse.self, from: data)
    }

    func fetchDiagnostics() async throws -> ArchitectureAuditReport {
        let prefix = try await resolveAPIPrefix()
        let url = baseURL.appendingPathComponent(prefix).appendingPathComponent("diagnostics/architecture")
        
        let (data, response) = try await performDataRequest(url: url)
        try validateResponse(response, data: data)
        
        return try JSONDecoder().decode(ArchitectureAuditReport.self, from: data)
    }

    @discardableResult
    func streamRiskSurface(
        bounds: BoundingBox,
        limit: Int = 256,
        onPayload: @escaping @MainActor (RiskSurfaceStreamPayload) -> Void,
        onFailure: @escaping @MainActor (String) -> Void
    ) -> Task<Void, Never> {
        Task {
            let socket: URLSessionWebSocketTask
            do {
                let prefix = try await resolveAPIPrefix()
                let url = try makeWebSocketURL(prefix: prefix, endpoint: "risk/ws")
                socket = session.webSocketTask(with: url)
                socket.resume()

                let subscribe = WebSocketEnvelope(
                    event: "risk.surface.subscribe",
                    data: RiskSurfaceSubscriptionRequest(
                        minLat: bounds.minLat,
                        maxLat: bounds.maxLat,
                        minLng: bounds.minLng,
                        maxLng: bounds.maxLng,
                        limit: limit
                    )
                )
                let body = try JSONEncoder().encode(subscribe)
                try await socket.send(.data(body))

                defer {
                    socket.cancel(with: .goingAway, reason: nil)
                }

                let decoder = JSONDecoder()
                while !Task.isCancelled {
                    let message = try await socket.receive()
                    let payloadData: Data
                    switch message {
                    case .data(let data):
                        payloadData = data
                    case .string(let string):
                        payloadData = Data(string.utf8)
                    @unknown default:
                        continue
                    }

                    guard let envelope = try? decoder.decode(RiskSurfaceStreamEnvelope.self, from: payloadData) else {
                        continue
                    }

                    switch envelope.event {
                    case "risk.surface.sync", "risk.surface.update":
                        if let payload = envelope.data {
                            await MainActor.run {
                                onPayload(payload)
                            }
                        }
                    case "risk.surface.error":
                        await MainActor.run {
                            onFailure("Risk surface stream rejected the subscription.")
                        }
                    default:
                        break
                    }
                }
            } catch is CancellationError {
                return
            } catch let error as APIClientError {
                await MainActor.run {
                    onFailure(error.localizedDescription)
                }
            } catch let error as URLError {
                await MainActor.run {
                    onFailure(APIClientError.connectivity(baseURL: baseURL.absoluteString, underlying: error).localizedDescription)
                }
            } catch {
                await MainActor.run {
                    onFailure(error.localizedDescription)
                }
            }
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard 200..<300 ~= httpResponse.statusCode else {
            throw APIClientError.invalidResponse(
                statusCode: httpResponse.statusCode,
                body: String(data: data, encoding: .utf8) ?? "No response body"
            )
        }
    }

    private func resolveAPIPrefix() async throws -> String {
        if let cached = resolvedAPIPrefix { return cached }

        let primaryURL = baseURL
            .appendingPathComponent(Self.primaryAPIPrefix)
            .appendingPathComponent("health")
        let legacyURL = baseURL
            .appendingPathComponent(Self.legacyAPIPrefix)
            .appendingPathComponent("health")

        let prefixes = [
            (Self.primaryAPIPrefix, primaryURL),
            (Self.legacyAPIPrefix, legacyURL)
        ]

        var lastConnectivityError: URLError?

        for (prefix, url) in prefixes {
            do {
                let (_, response) = try await performDataRequest(url: url)
                guard let http = response as? HTTPURLResponse else { continue }
                if 200..<500 ~= http.statusCode, http.statusCode != 404 {
                    resolvedAPIPrefix = prefix
                    return prefix
                }
            } catch let error as URLError {
                lastConnectivityError = error
            } catch {
                continue
            }
        }

        if let connectivityError = lastConnectivityError {
            throw APIClientError.connectivity(baseURL: baseURL.absoluteString, underlying: connectivityError)
        }
        throw APIClientError.invalidResponse(statusCode: 404, body: "No supported API prefix found at /api/v1 or /api")
    }

    private func makeWebSocketURL(prefix: String, endpoint: String) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        guard let rootURL = components.url else {
            throw URLError(.badURL)
        }
        return rootURL.appendingPathComponent(prefix).appendingPathComponent(endpoint)
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
