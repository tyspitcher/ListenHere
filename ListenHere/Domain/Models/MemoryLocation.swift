// Defines framework-neutral location values, candidate provenance, and validation shared by capture and browsing.

import Foundation

enum MemoryLocationSource: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case photoMetadata
    case deviceCapture
    case manualPin

    var displayName: String {
        switch self {
        case .photoMetadata: "Photo Location"
        case .deviceCapture: "Current Location"
        case .manualPin: "Pinned Location"
        }
    }
}

struct MemoryLocation: Codable, Equatable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
    var name: String?
    var source: MemoryLocationSource

    init(latitude: Double, longitude: Double, name: String? = nil, source: MemoryLocationSource = .manualPin) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.source = source
    }

    var isValid: Bool {
        (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }

    var displayName: String {
        if let normalizedName { return normalizedName }
        return source.displayName
    }

    var coordinateDescription: String {
        String(format: "%.4f°, %.4f°", latitude, longitude)
    }

    var normalizedName: String? {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName?.isEmpty == false ? trimmedName : nil
    }

    func representsSamePlace(as other: MemoryLocation) -> Bool {
        latitude == other.latitude
            && longitude == other.longitude
            && source == other.source
    }
}

struct MemoryLocationCandidate: Codable, Equatable, Hashable, Identifiable, Sendable {
    let location: MemoryLocation

    var id: String {
        "\(location.source.rawValue)-\(location.latitude)-\(location.longitude)"
    }
}
