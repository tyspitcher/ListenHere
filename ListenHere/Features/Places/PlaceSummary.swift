// Provides framework-neutral map annotations and their camera-dependent memory clusters.

import Foundation

struct PlaceSummary: Identifiable, Equatable {
    let id: String
    let location: MemoryLocation
    let memories: [MemorySummary]

    var title: String {
        location.name ?? "Nearby Memories"
    }

    var subtitle: String {
        "\(memories.count) \(memories.count == 1 ? "memory" : "memories")"
    }
}

struct PlaceCluster: Identifiable, Equatable {
    let id: String
    let location: MemoryLocation
    let memories: [MemorySummary]

    var title: String {
        if memories.count == 1 {
            return location.name ?? "Memory Location"
        }
        return "Nearby Memories"
    }

    var subtitle: String {
        "\(memories.count) \(memories.count == 1 ? "memory" : "memories")"
    }
}
