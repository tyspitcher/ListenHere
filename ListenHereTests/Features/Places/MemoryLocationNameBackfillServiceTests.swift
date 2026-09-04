import Foundation
import Testing
@testable import ListenHere

struct MemoryLocationNameBackfillServiceTests {
    @Test("Names and persists an unnamed saved location")
    @MainActor
    func namesAndPersistsLocation() async {
        let location = MemoryLocation(
            latitude: 37.2982,
            longitude: -113.0263,
            source: .photoMetadata
        )
        let repository = BackfillRepositoryStub()
        let service = MemoryLocationNameBackfillService(
            repository: repository,
            locationNameResolver: LocationNameResolverStub(name: "Zion National Park")
        )

        let memory = makeMemory(location: location)
        let namedMemory = await service.resolveMissingNames(in: [memory]).first

        #expect(namedMemory?.location?.name == "Zion National Park")
        #expect(namedMemory?.locationCandidates.first?.location.name == "Zion National Park")
        #expect(repository.persistedLocation?.name == "Zion National Park")
    }

    @Test("Does not replace a location changed after the browse snapshot")
    @MainActor
    func preservesNewerLocationSelection() async {
        let location = MemoryLocation(
            latitude: 40.6097,
            longitude: -111.9391,
            source: .deviceCapture
        )
        let repository = BackfillRepositoryStub(shouldPersist: false)
        let service = MemoryLocationNameBackfillService(
            repository: repository,
            locationNameResolver: LocationNameResolverStub(name: "West Jordan, UT")
        )

        let memory = makeMemory(location: location)
        let result = await service.resolveMissingNames(in: [memory]).first

        #expect(result?.location?.name == nil)
        #expect(repository.persistedLocation?.name == "West Jordan, UT")
    }

    private func makeMemory(location: MemoryLocation) -> MemorySummary {
        MemorySummary(
            id: UUID(),
            title: "Morning Walk",
            caption: nil,
            capturedAt: Date(),
            thumbnail: nil,
            hasAudio: true,
            audioDurationSeconds: 12,
            locationName: nil,
            location: location,
            locationCandidates: [MemoryLocationCandidate(location: location)],
            journalNames: []
        )
    }
}

@MainActor
private final class BackfillRepositoryStub: MemoryRepository {
    let shouldPersist: Bool
    private(set) var persistedLocation: MemoryLocation?

    init(shouldPersist: Bool = true) {
        self.shouldPersist = shouldPersist
    }

    func fetchActiveMemories() async throws -> [MemorySummary] { [] }
    func fetchActiveMemories(journalID _: UUID) async throws -> [MemorySummary] { [] }
    func fetchActiveMemory(id _: UUID) async throws -> MemorySummary? { nil }
    func createMemory(from _: MemoryDraft, origin _: MemoryCreationOrigin) throws -> Memory {
        throw BackfillTestError.unused
    }
    func updateJournalAssignments(memoryID _: UUID, journalIDs _: Set<UUID>) throws {}
    func moveToRecentlyDeleted(memoryID _: UUID, at _: Date) throws {}

    func persistResolvedLocationName(memoryID _: UUID, location: MemoryLocation) throws -> Bool {
        persistedLocation = location
        return shouldPersist
    }
}

@MainActor
private final class LocationNameResolverStub: LocationNameResolving {
    let resolvedName: String?

    init(name: String?) {
        resolvedName = name
    }

    func name(for _: MemoryLocation) async throws -> String? {
        resolvedName
    }
}

private enum BackfillTestError: Error {
    case unused
}
