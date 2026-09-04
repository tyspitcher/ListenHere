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

    @Test("Loading a journal resolves its current name for the navigation title")
    func loadResolvesJournalTitle() async {
        let journalID = UUID()
        let viewModel = JournalDetailViewModel(
            journalID: journalID,
            repository: JournalMemoryRepositoryStub(memories: []),
            journalRepository: JournalRepositoryStub(journals: [
                JournalSummary(
                    id: journalID,
                    name: "Weekend Walks",
                    memoryCount: 0,
                    isDefault: false,
                    isSystemUnassigned: false
                ),
            ])
        )

        await viewModel.load()

        #expect(viewModel.journalTitle == "Weekend Walks")
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

@MainActor
private final class JournalRepositoryStub: JournalRepository {
    let journals: [JournalSummary]

    init(journals: [JournalSummary]) {
        self.journals = journals
    }

    func fetchActiveJournals() async throws -> [JournalSummary] { journals }
    func createJournal(name: String, at date: Date) throws -> Journal { throw JournalDetailTestError.unavailable }
    func renameJournal(id: UUID, name: String, at date: Date) throws { throw JournalDetailTestError.unavailable }
    func setDefaultJournal(id: UUID, at date: Date) throws { throw JournalDetailTestError.unavailable }
    func moveToRecentlyDeleted(
        journalID: UUID,
        strategy: JournalDeletionStrategy,
        at date: Date
    ) throws { throw JournalDetailTestError.unavailable }
}

private enum JournalDetailTestError: Error {
    case unavailable
}
