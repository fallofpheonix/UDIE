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

    var body: some Scene {
        WindowGroup {
            MapView()
                .environmentObject(appState)
                .environmentObject(locationManager)
        }
    }
}
