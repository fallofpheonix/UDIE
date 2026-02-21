import SwiftUI

struct EventDetailModal: View {
    let event: GeoEvent

    var body: some View {
        EventDetailView(event: event)
    }
}
