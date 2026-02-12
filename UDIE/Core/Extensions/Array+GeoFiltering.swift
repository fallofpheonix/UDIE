//
//  Array+GeoFiltering.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import Foundation
import CoreLocation

extension Array where Element == GeoEvent {

    func filtered(minSeverity: Int) -> [GeoEvent] {
        self.filter { $0.severity >= minSeverity }
    }
}
