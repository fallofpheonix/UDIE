import SwiftUI

struct ScenarioSimulationView: View {
    @State private var selectedEventType = 0
    @State private var intensity: Double = 5.0
    @State private var duration: Double = 4.0
    @State private var isSimulating = false
    
    var body: some View {
        NavigationView {
            ZStack {
                ColorTokens.adaptiveBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Selector
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Event Injection")
                                .font(Typography.heading)
                            
                            Picker("Event Type", selection: $selectedEventType) {
                                Text("Major Flooding").tag(0)
                                Text("Infrastructure Failure").tag(1)
                                Text("Public Protest").tag(2)
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding()
                        .background(ColorTokens.adaptiveSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // 2. Intensity & Duration
                        VStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Intensity")
                                    Spacer()
                                    Text("\(Int(intensity))")
                                }
                                .font(Typography.body.bold())
                                Slider(value: $intensity, in: 1...10)
                            }
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Duration (Hours)")
                                    Spacer()
                                    Text("\(Int(duration))h")
                                }
                                .font(Typography.body.bold())
                                Slider(value: $duration, in: 1...24)
                            }
                        }
                        .padding()
                        .background(ColorTokens.adaptiveSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // 3. Action
                        Button(action: { runSimulation() }) {
                            if isSimulating {
                                ProgressView().tint(.white)
                            } else {
                                Text("Deploy Simulation")
                                    .font(Typography.body.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSimulating ? ColorTokens.textSecondary : ColorTokens.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(isSimulating)
                        
                        // 4. Forecasted Impact
                        if !isSimulating {
                            ImpactSection()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Simulation")
        }
    }
    
    private func runSimulation() {
        isSimulating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isSimulating = false
        }
    }
}

struct ImpactSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Forecasted Impact")
                .font(Typography.heading)
            
            HStack(spacing: 16) {
                ImpactMetricCard(title: "Route Reliability", value: "-42%", color: ColorTokens.highRisk)
                ImpactMetricCard(title: "Risk Shift", value: "+1.2", color: ColorTokens.mediumRisk)
            }
        }
    }
}

struct ImpactMetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
            Text(value)
                .font(Typography.heading)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ColorTokens.adaptiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ColorTokens.cardStroke))
    }
}
