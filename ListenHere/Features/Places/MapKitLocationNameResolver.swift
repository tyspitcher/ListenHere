// Uses MapKit reverse geocoding to describe a coordinate without exposing MapKit to feature state.

import CoreLocation
import Foundation
import MapKit

@MainActor
final class MapKitLocationNameResolver: LocationNameResolving {
    func name(for location: MemoryLocation) async throws -> String? {
        guard location.isValid else { throw LocationNameResolutionError.invalidCoordinate }

        let coreLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        guard let request = MKReverseGeocodingRequest(location: coreLocation) else {
            throw LocationNameResolutionError.invalidCoordinate
        }

        // MapKit performs the network-backed coordinate lookup and returns Apple Maps place data.
        // The request stays behind this protocol boundary so views and domain models remain free of
        // framework types. No additional location permission is needed because this converts an
        // already-selected coordinate; Core Location authorization is handled by the separate
        // CurrentLocationProviding adapter when the device's position is requested.
        let mapItems = try await withTaskCancellationHandler {
            try await request.mapItems
        } onCancel: {
            request.cancel()
        }

        guard let mapItem = mapItems.first else { return nil }
        return Self.displayName(for: mapItem)
    }

    private static func displayName(for mapItem: MKMapItem) -> String? {
        if mapItem.pointOfInterestCategory != nil,
           let pointOfInterestName = normalized(mapItem.name) {
            return pointOfInterestName
        }

        if let city = normalized(mapItem.addressRepresentations?.cityWithContext) {
            return city
        }

        if let region = normalized(mapItem.addressRepresentations?.regionName) {
            return region
        }

        return normalized(mapItem.name) ?? normalized(mapItem.address?.shortAddress)
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue?.isEmpty == false ? trimmedValue : nil
    }
}
