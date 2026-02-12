//
//  EventFilter.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import Foundation

struct EventFilter {

    static let defaultMinSeverity = 1
    static let defaultMinConfidence = 0.0

    var selectedTypes: Set<EventType> = Set(EventType.allCases)
    var minSeverity: Int = defaultMinSeverity
    var minConfidence: Double = defaultMinConfidence

    mutating func reset() {
        selectedTypes = Set(EventType.allCases)
        minSeverity = Self.defaultMinSeverity
        minConfidence = Self.defaultMinConfidence
    }
}
