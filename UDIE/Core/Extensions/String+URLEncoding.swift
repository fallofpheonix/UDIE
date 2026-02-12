//
//  String+URLEncoding.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import Foundation

extension String {

    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
