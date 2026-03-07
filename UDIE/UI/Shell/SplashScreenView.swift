import SwiftUI
import Combine

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var opacity = 0.5
    @State private var size = 0.8
    
    var body: some View {
        if isActive {
            MainContainerView()
        } else {
            ZStack {
                ColorTokens.appBackground
                    .ignoresSafeArea()
                
                // Soft animated gradient background
                LinearGradient(
                    colors: [ColorTokens.accent.opacity(0.1), ColorTokens.lowRisk.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack {
                        Image(systemName: "shield.righthalf.filled")
                            .font(.system(size: 80))
                            .foregroundStyle(ColorTokens.accent)
                        
                        Text("UDIE")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(ColorTokens.textPrimary)
                        
                        Text("Urban Disruption Intelligence Engine")
                            .font(.subheadline)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .scaleEffect(size)
                    .opacity(opacity)
                    
                    ProgressView()
                        .tint(ColorTokens.accent)
                        .padding(.top, 40)
                }
            }
            .onAppear {
                withAnimation(.easeIn(duration: 1.2)) {
                    self.size = 0.9
                    self.opacity = 1.0
                }
                
                // Splash duration 1.5s
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
}
