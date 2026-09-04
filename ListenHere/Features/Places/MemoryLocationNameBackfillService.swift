// Resolves and persists missing names for already-saved location coordinates.

import Foundation

@MainActor
protocol MemoryLocationNameBackfilling {
    func resolveMissingNames(in memories: [MemorySummary]) async -> [MemorySummary]
}

@MainActor
final class MemoryLocationNameBackfillService: MemoryLocationNameBackfilling {
    private let repository: any MemoryRepository
    private let locationNameResolver: any LocationNameResolving

    init(
        repository: any MemoryRepository,
        locationNameResolver: any LocationNameResolving
    ) {
        self.repository = repository
        self.locationNameResolver = locationNameResolver
    }

    func resolveMissingNames(in memories: [MemorySummary]) async -> [MemorySummary] {
        var resolvedMemories = memories

        for index in resolvedMemories.indices {
            guard Task.isCancelled == false,
                  let location = resolvedMemories[index].location,
                  location.normalizedName == nil else {
                continue
            }

            do {
                guard let name = try await locationNameResolver.name(for: location) else { continue }
                try Task.checkCancellation()
                var namedLocation = location
                namedLocation.name = name
                guard try repository.persistResolvedLocationName(
                    memoryID: resolvedMemories[index].id,
                    location: namedLocation
                ) else {
                    continue
                }
                resolvedMemories[index] = resolvedMemories[index].replacingLocation(namedLocation)
            } catch is CancellationError {
                return memories
            } catch {
                // A transient Maps or persistence failure is non-blocking. Another browse pass
                // can retry later, and the original coordinate remains available in the meantime.
                continue
            }
        }

        return resolvedMemories
    }
}
