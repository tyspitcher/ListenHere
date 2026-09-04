// Defines the one-shot device-location capability consumed by capture without exposing Core Location.

import Foundation

@MainActor
protocol CurrentLocationProviding {
    func requestCurrentLocation() async throws -> MemoryLocationCandidate
}

enum CurrentLocationError: Error, Equatable {
    case permissionDenied
    case unavailable
    case requestInProgress
}
