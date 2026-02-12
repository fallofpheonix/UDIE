//
//  EventDetailView.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//


import SwiftUI
import CoreLocation

struct EventDetailView: View {

    let event: GeoEvent

    var body: some View {

        VStack(alignment: .leading, spacing: 20) {

            // MARK: Header
            HStack(spacing: 10) {

                Circle()
                    .fill(event.eventType.displayColor)
                    .frame(width: 14, height: 14)

                Text(event.eventType.displayName)
                    .font(.title2)
                    .bold()
            }

            Divider()

            // MARK: Severity
            VStack(alignment: .leading, spacing: 6) {

                Text("Severity")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ProgressView(
                    value: Double(event.severity),
                    total: 5
                )
            }

            // MARK: Confidence
            VStack(alignment: .leading, spacing: 6) {

                Text("Confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ProgressView(
                    value: event.confidence
                )
            }

            Divider()

            // MARK: Coordinates
            VStack(alignment: .leading, spacing: 4) {

                Text("Latitude: \(event.latitude)")
                Text("Longitude: \(event.longitude)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
