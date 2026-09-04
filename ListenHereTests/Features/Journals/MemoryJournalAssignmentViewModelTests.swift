import Foundation
import Testing
@testable import ListenHere

struct MemoryJournalAssignmentViewModelTests {
    @Test("Loading excludes the protected Unassigned journal")
    @MainActor
    func loadFiltersProtectedJournal() async {
        let selectedJournal = makeJournal(name: "Family")
        let protectedJournal = JournalSummary(
            id: UUID(),
            name: "Unassigned",
            memoryCount: 0,
            isDefault: false,
            isSystemUnassigned: true
        )
        let viewModel = MemoryJournalAssignmentViewModel(
            memory: makeMemory(journalID: selectedJournal.id),
            memoryRepository: MemoryRepositoryStub(),
            journalRepository: JournalRepositoryStub(journals: [selectedJournal, protectedJournal])
        )

        await viewModel.load()

        #expect(viewModel.state == .loaded)
        #expect(viewModel.journals == [selectedJournal])
        #expect(viewModel.selectedJournalIDs == [selectedJournal.id])
    }

    @Test("Applying a nonempty valid selection updates the saved memory")
    @MainActor
    func applySelectionUpdatesMemory() async {
        let firstJournal = makeJournal(name: "Family")
        let secondJournal = makeJournal(name: "Everyday")
        let memoryRepository = MemoryRepositoryStub()
        let viewModel = MemoryJournalAssignmentViewModel(
            memory: makeMemory(journalID: firstJournal.id),
            memoryRepository: memoryRepository,
            journalRepository: JournalRepositoryStub(journals: [firstJournal, secondJournal])
        )
        await viewModel.load()

        let didApply = viewModel.applySelection([firstJournal.id, secondJournal.id])

        #expect(didApply)
        #expect(memoryRepository.updatedJournalIDs == [firstJournal.id, secondJournal.id])
    }

    @Test("Creating a journal makes it available for immediate assignment")
    @MainActor
    func createJournalRefreshesChoices() async {
        let existingJournal = makeJournal(name: "Family")
        let repository = JournalRepositoryStub(journals: [existingJournal])
        let viewModel = MemoryJournalAssignmentViewModel(
            memory: makeMemory(journalID: existingJournal.id),
            memoryRepository: MemoryRepositoryStub(),
            journalRepository: repository
        )
        await viewModel.load()

        let created = await viewModel.createJournal("Weekend Walks")

        #expect(created?.name == "Weekend Walks")
        #expect(viewModel.journals.contains { $0.id == created?.id })
    }

    private func makeMemory(journalID: UUID) -> MemorySummary {
        MemorySummary(
            id: UUID(),
            title: "Picnic",
            caption: nil,
            capturedAt: .now,
            thumbnail: nil,
            hasAudio: false,
            audioDurationSeconds: nil,
            locationName: nil,
            journalIDs: [journalID],
            journalNames: ["Family"]
        )
    }

    private func makeJournal(name: String) -> JournalSummary {
        JournalSummary(
            id: UUID(),
            name: name,
            memoryCount: 1,
            isDefault: false,
            isSystemUnassigned: false
        )
    }
}

@MainActor
private final class MemoryRepositoryStub: MemoryRepository {
    private(set) var updatedJournalIDs: Set<UUID> = []

    func fetchActiveMemories() async throws -> [MemorySummary] { [] }
    func fetchActiveMemories(journalID: UUID) async throws -> [MemorySummary] { [] }
    func fetchActiveMemory(id: UUID) async throws -> MemorySummary? { nil }
    func createMemory(from draft: MemoryDraft, origin: MemoryCreationOrigin) throws -> Memory {
        throw MemoryAssignmentTestError.unavailable
    }
    func updateJournalAssignments(memoryID: UUID, journalIDs: Set<UUID>) throws {
        updatedJournalIDs = journalIDs
    }
    func moveToRecentlyDeleted(memoryID: UUID, at date: Date) throws {}
}

@MainActor
private final class JournalRepositoryStub: JournalRepository {
    private(set) var journals: [JournalSummary]

    init(journals: [JournalSummary]) {
        self.journals = journals
    }

    func fetchActiveJournals() async throws -> [JournalSummary] { journals }
    func createJournal(name: String, at date: Date) throws -> Journal {
        let journal = Journal(name: name, createdAt: date, modifiedAt: date)
        journals.append(
            JournalSummary(
                id: journal.id,
                name: journal.name,
                memoryCount: 0,
                isDefault: journal.isDefault,
                isSystemUnassigned: journal.isSystemUnassigned
            )
        )
        return journal
    }
    func renameJournal(id: UUID, name: String, at date: Date) throws {
        throw MemoryAssignmentTestError.unavailable
    }
    func setDefaultJournal(id: UUID, at date: Date) throws {
        throw MemoryAssignmentTestError.unavailable
    }
    func moveToRecentlyDeleted(
        journalID: UUID,
        strategy: JournalDeletionStrategy,
        at date: Date
    ) throws {
        throw MemoryAssignmentTestError.unavailable
    }
}

private enum MemoryAssignmentTestError: Error {
    case unavailable
}
