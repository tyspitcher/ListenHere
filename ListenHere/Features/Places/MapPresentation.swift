// Defines the display-only base-map choices shared by Places browsing and manual pin placement.

import MapKit
import SwiftUI

enum MapPresentation: String, CaseIterable, Identifiable {
    case explore
    case satellite

    var id: Self { self }

    var title: String {
        switch self {
        case .explore: "Explore"
        case .satellite: "Satellite"
        }
    }

    var symbolName: String {
        switch self {
        case .explore: "map"
        case .satellite: "globe.americas.fill"
        }
    }

    var mapStyle: MapStyle {
        switch self {
        case .explore: .standard
        case .satellite: .imagery
        }
    }
}
