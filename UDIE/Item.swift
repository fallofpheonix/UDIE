//
//  Item.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
