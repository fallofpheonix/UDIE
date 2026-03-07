//
//  UDIEApp.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import Foundation
import SwiftUI
import Combine

@main
struct UDIEApp: App {

    @StateObject private var appState = AppState()
    @StateObject private var locationManager = LocationManager()

    @State private var isSplashActive = true

    var body: some Scene {
        WindowGroup {
            if isSplashActive {
                SplashScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                isSplashActive = false
                            }
                        }
                    }
                    .environmentObject(appState)
                    .environmentObject(locationManager)
            } else {
                AppRouter()
                    .environmentObject(appState)
                    .environmentObject(locationManager)
            }
        }
    }
}
