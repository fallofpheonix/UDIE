import SwiftUI

struct SettingsView: View {
    @State private var themeSelection = 2 // System
    @State private var forecastEnabled = true
    @State private var reliabilityEnabled = false
    @State private var defaultCity = "Delhi"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Visual Theme")) {
                    Picker("Theme", selection: $themeSelection) {
                        Text("Light").tag(0)
                        Text("Dark").tag(1)
                        Text("System").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Map Layers")) {
                    Toggle("Forecast Overlay", isOn: $forecastEnabled)
                    Toggle("Reliability Layer", isOn: $reliabilityEnabled)
                }
                
                Section(header: Text("Preferences")) {
                    NavigationLink(destination: Text("Select City")) {
                        HStack {
                            Text("Default City")
                            Spacer()
                            Text(defaultCity).foregroundStyle(ColorTokens.textSecondary)
                        }
                    }
                }
                
                Section(header: Text("Notifications")) {
                    Toggle("High Risk Alerts", isOn: .constant(true))
                }
                
                Section {
                    Button("Export Diagnostics", action: {})
                        .foregroundStyle(ColorTokens.accent)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
