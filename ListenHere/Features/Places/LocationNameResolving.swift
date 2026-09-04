// Defines the reverse-geocoding boundary that turns coordinates into a user-facing area name.

import Foundation

@MainActor
protocol LocationNameResolving {
    func name(for location: MemoryLocation) async throws -> String?
}

enum LocationNameResolutionError: Error, Equatable {
    case invalidCoordinate
}
