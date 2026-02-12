//
//  EventFilter.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import Foundation
import Combine

final class EventFilter: ObservableObject {

    @Published var selectedTypes: Set<EventType> = Set(EventType.allCases)
    @Published var minSeverity: Int = 1
    @Published var minConfidence: Double = 0.0
}
