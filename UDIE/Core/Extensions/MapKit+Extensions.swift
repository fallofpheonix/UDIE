//
//  MapKit+Extensions.swift
//  UDIE
//
//  Created by Ujjwal Singh on 13/02/26.
//

import MapKit

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = Array(
            repeating: kCLLocationCoordinate2DInvalid,
            count: pointCount
        )
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
