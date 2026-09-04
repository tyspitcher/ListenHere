// Adapts Core Location's delegate callbacks into the one-shot async location capability used by capture.

import CoreLocation
import Foundation

@MainActor
final class CoreLocationCurrentLocationProvider: NSObject, CurrentLocationProviding, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private var continuation: CheckedContinuation<MemoryLocationCandidate, Error>?

    override init() {
        manager = CLLocationManager()
        super.init()
        // Core Location owns authorization and the short-lived GPS/Wi-Fi lookup. Keeping it in
        // this adapter prevents framework delegates and permission states leaking into capture.
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentLocation() async throws -> MemoryLocationCandidate {
        guard continuation == nil else { throw CurrentLocationError.requestInProgress }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return try await requestLocationFix()
        case .notDetermined:
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        case .denied, .restricted:
            throw CurrentLocationError.permissionDenied
        @unknown default:
            throw CurrentLocationError.unavailable
        }
    }

    func locationManagerDidChangeAuthorization(_: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            // requestLocation() returns one fix and stops location services; capture never tracks
            // in the background or continuously after this candidate has been collected.
            manager.requestLocation()
        case .denied, .restricted:
            finish(with: .failure(CurrentLocationError.permissionDenied))
        case .notDetermined:
            break
        @unknown default:
            finish(with: .failure(CurrentLocationError.unavailable))
        }
    }

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            finish(with: .failure(CurrentLocationError.unavailable))
            return
        }
        finish(with: .success(MemoryLocationCandidate(
            location: MemoryLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                source: .deviceCapture
            )
        )))
    }

    func locationManager(_: CLLocationManager, didFailWithError _: Error) {
        finish(with: .failure(CurrentLocationError.unavailable))
    }

    private func requestLocationFix() async throws -> MemoryLocationCandidate {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    private func finish(with result: Result<MemoryLocationCandidate, Error>) {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(with: result)
    }
}
