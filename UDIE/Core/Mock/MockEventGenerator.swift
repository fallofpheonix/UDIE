//
//  MockEventGenerator.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import Foundation
import CoreLocation

struct MockEventGenerator {

    static func generate(in region: MKCoordinateRegion, count: Int = 250) -> [GeoEvent] {

        var events: [GeoEvent] = []

        for _ in 0..<count {

            let latOffset = Double.random(in: -region.span.latitudeDelta/2...region.span.latitudeDelta/2)
            let lngOffset = Double.random(in: -region.span.longitudeDelta/2...region.span.longitudeDelta/2)

            let event = GeoEvent(
                id: UUID(),
                eventType: EventType.allCases.randomElement()!,
                severity: Int.random(in: 1...5),
                confidence: Double.random(in: 0.5...1.0),
                latitude: region.center.latitude + latOffset,
                longitude: region.center.longitude + lngOffset
            )

            events.append(event)
        }

        return events
    }
}

