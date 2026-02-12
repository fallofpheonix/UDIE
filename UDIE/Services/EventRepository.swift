//
//  EventRepository.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//


import Foundation

final class EventRepository {

    func getEvents(
        minLat: Double,
        maxLat: Double,
        minLng: Double,
        maxLng: Double
    ) async throws -> [GeoEvent] {

        try await APIClient.shared.fetchEvents(
            minLat: minLat,
            maxLat: maxLat,
            minLng: minLng,
            maxLng: maxLng
        )
    }
}
