//
//  MKCoordinateRegion+BoundingBox.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//

import MapKit

extension MKCoordinateRegion {

    var boundingBox: BoundingBox {

        let minLat = center.latitude - span.latitudeDelta / 2
        let maxLat = center.latitude + span.latitudeDelta / 2
        let minLng = center.longitude - span.longitudeDelta / 2
        let maxLng = center.longitude + span.longitudeDelta / 2

        return BoundingBox(
            minLat: minLat,
            maxLat: maxLat,
            minLng: minLng,
            maxLng: maxLng
        )
    }
}
