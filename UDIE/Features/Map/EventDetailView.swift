//
//  EventDetailView.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import SwiftUI

struct EventDetailView: View {

    let event: GeoEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Header
            HStack {
                Circle()
                    .fill(event.eventType.displayColor)
                    .frame(width: 14, height: 14)

                Text(event.eventType.displayName)
                    .font(.title2)
                    .bold()
            }

            // Severity
            VStack(alignment: .leading, spacing: 6) {
                Text("Severity")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ProgressView(value: Double(event.severity), total: 5)
            }

            // Confidence
            VStack(alignment: .leading, spacing: 6) {
                Text("Confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ProgressView(value: event.confidence)
            }

            Spacer()
        }
        .padding()
    }
}
