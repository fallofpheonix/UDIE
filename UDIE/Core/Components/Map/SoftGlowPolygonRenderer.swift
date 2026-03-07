import MapKit
import UIKit

final class SoftGlowPolygonRenderer: MKPolygonRenderer {
    var glowColor: UIColor = .clear
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        // Draw the soft glow shadow
        context.saveGState()
        context.setShadow(
            offset: .zero,
            blur: 8 / zoomScale,
            color: glowColor.withAlphaComponent(0.4).cgColor
        )
        
        // Draw the actual polygon
        super.draw(mapRect, zoomScale: zoomScale, in: context)
        context.restoreGState()
        
        // Add a subtle inner gradient or highlight if needed
        // For current polish, the shadow-based glow is sufficient.
    }
}
