//
//  FilterView.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import SwiftUI

struct FilterView: View {

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {

        VStack(alignment: .leading, spacing: 20) {

            Text("Filters")
                .font(.title2)
                .bold()

            // Event Types
            VStack(alignment: .leading, spacing: 10) {

                Text("Event Types")
                    .font(.headline)

                ForEach(EventType.allCases, id: \.self) { type in
                    Toggle(
                        type.displayName,
                        isOn: Binding(
                            get: {
                                appState.filters.selectedTypes.contains(type)
                            },
                            set: { isOn in
                                if isOn {
                                    appState.filters.selectedTypes.insert(type)
                                } else {
                                    appState.filters.selectedTypes.remove(type)
                                }
                            }
                        )
                    )
                }
            }

            // Severity
            VStack(alignment: .leading) {
                Text("Minimum Severity: \(appState.filters.minSeverity)")
                Slider(
                    value: Binding(
                        get: { Double(appState.filters.minSeverity) },
                        set: { appState.filters.minSeverity = Int($0) }
                    ),
                    in: 1...5,
                    step: 1
                )
            }

            // Confidence
            VStack(alignment: .leading) {
                Text("Minimum Confidence: \(Int(appState.filters.minConfidence * 100))%")
                Slider(
                    value: $appState.filters.minConfidence,
                    in: 0...1
                )
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
