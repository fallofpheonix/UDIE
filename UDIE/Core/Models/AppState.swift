//
//  AppState.swift
//  UDIE
//
//  Created by Ujjwal Singh on 13/02/26.
//

import Foundation
import Combine
final class AppState: ObservableObject {
    @Published var filters = EventFilter()
}
