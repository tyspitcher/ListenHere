import Foundation
import Testing
@testable import ListenHere

@MainActor
struct JournalDetailViewModelTests {
    @Test("Loading a journal resolves managed photos for its memory cards")
    func loadResolvesManagedPhotoURL() async throws {
        let mediaStore = InMemoryManagedMediaStore()
        let file = try mediaStore.store(Data("photo".utf8), as: .photo, preferredFileExtension: "heic")
        let memory = MemorySummary(
            id: UUID(),
            title: "Park",
            caption: nil,
            capturedAt: .init(timeIntervalSince1970: 1),
            thumbnail: .managedFile(file.filename),
            hasAudio: false,
            audioDurationSeconds: nil,
            locationName: nil,
            journalNames: []
        )
        let viewModel = JournalDetailViewModel(
            journalID: UUID(),
            repository: JournalMemoryRepositoryStub(memories: [memory]),
            mediaReader: mediaStore
        )

        await viewModel.load()

        #expect(viewModel.managedPhotoURL(for: memory) == URL(filePath: "/in-memory/\(file.filename)"))
    }
}

@MainActor
private final class JournalMemoryRepositoryStub: MemoryRepository {
    private let memories: [MemorySummary]

    init(memories: [MemorySummary]) {
        self.memories = memories
    }

    func fetchActiveMemories() async throws -> [MemorySummary] { memories }
    func fetchActiveMemories(journalID: UUID) async throws -> [MemorySummary] { memories }
    func fetchActiveMemory(id: UUID) async throws -> MemorySummary? {
        memories.first(where: { $0.id == id })
    }
    func createMemory(from draft: MemoryDraft, origin: MemoryCreationOrigin) throws -> Memory {
        throw JournalDetailTestError.unavailable
    }
    func updateJournalAssignments(memoryID: UUID, journalIDs: Set<UUID>) throws {
        throw JournalDetailTestError.unavailable
    }
    func moveToRecentlyDeleted(memoryID: UUID, at date: Date) throws {
        throw JournalDetailTestError.unavailable
    }
}

private enum JournalDetailTestError: Error {
    case unavailable
}
