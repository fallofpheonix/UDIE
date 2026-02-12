//
//  Date+Formatting.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import Foundation

extension Date {

    func formattedShort() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
