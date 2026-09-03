import Foundation
import Testing
@testable import ListenHere

@MainActor
struct JournalsViewModelTests {
    @Test("Deleting a non-empty journal first prepares the other journals as destinations")
    func preparesMoveDestinations() async throws {
        let source = makeJournal(name: "Trip", memoryCount: 3, isDefault: true)
        let defaultDestination = makeJournal(name: "Everyday", isDefault: true)
        let otherDestination = makeJournal(name: "Family")
        let repository = JournalRepositoryStub(
            journals: [source, otherDestination, defaultDestination]
        )
        let viewModel = JournalsViewModel(repository: repository)
        await viewModel.load()

        viewModel.requestDeletion(of: source)
        viewModel.prepareToMoveMemories()

        let request = try #require(viewModel.moveRequest)
        #expect(request.journal.id == source.id)
        #expect(request.destinations.map(\.id) == [defaultDestination.id, otherDestination.id])
        #expect(viewModel.journalPendingDeletion == nil)
    }

    @Test("The protected Unassigned journal is never a move destination")
    func excludesUnassignedDestination() async throws {
        let source = makeJournal(name: "Trip", memoryCount: 1)
        let unassigned = makeJournal(name: "Unassigned", isSystemUnassigned: true)
        let repository = JournalRepositoryStub(journals: [source, unassigned])
        let viewModel = JournalsViewModel(repository: repository)
        await viewModel.load()

        viewModel.requestDeletion(of: source)
        viewModel.prepareToMoveMemories()

        #expect(viewModel.moveRequest?.destinations.isEmpty == true)
    }

    @Test("Confirming a move sends the selected destination and refreshes journals")
    func confirmsMoveAndRefreshes() async throws {
        let source = makeJournal(name: "Trip", memoryCount: 2)
        let destination = makeJournal(name: "Everyday", isDefault: true)
        let repository = JournalRepositoryStub(journals: [source, destination])
        let viewModel = JournalsViewModel(repository: repository)
        await viewModel.load()
        viewModel.requestDeletion(of: source)
        viewModel.prepareToMoveMemories()
        repository.journals = [destination]

        let succeeded = await viewModel.moveMemoriesAndDeleteJournal(
            destinationID: destination.id
        )

        #expect(succeeded)
        #expect(repository.deletionRequests == [
            .init(
                journalID: source.id,
                strategy: .moveMemories(toJournalID: destination.id)
            ),
        ])
        #expect(viewModel.state == .loaded([destination]))
        #expect(viewModel.moveRequest == nil)
    }

    @Test("An unknown move destination is rejected before persistence")
    func rejectsUnknownDestination() async {
        let source = makeJournal(name: "Trip", memoryCount: 2)
        let destination = makeJournal(name: "Everyday")
        let repository = JournalRepositoryStub(journals: [source, destination])
        let viewModel = JournalsViewModel(repository: repository)
        await viewModel.load()
        viewModel.requestDeletion(of: source)
        viewModel.prepareToMoveMemories()

        let succeeded = await viewModel.moveMemoriesAndDeleteJournal(destinationID: UUID())

        #expect(succeeded == false)
        #expect(repository.deletionRequests.isEmpty)
        #expect(viewModel.errorMessage == "Choose another journal before continuing.")
    }

    @Test("Creating a journal reloads the collection")
    func createsJournal() async {
        let repository = JournalRepositoryStub(journals: [])
        let viewModel = JournalsViewModel(repository: repository)
        viewModel.requestJournalCreation()

        let succeeded = await viewModel.saveJournalName("Everyday")

        #expect(succeeded)
        #expect(repository.createdNames == ["Everyday"])
        #expect(viewModel.nameEditor == nil)
        #expect(viewModel.state == .loaded(repository.journals))
    }

    @Test("Renaming a journal persists the trimmed name and reloads the collection")
    func renamesJournal() async {
        let journal = makeJournal(name: "Trip")
        let repository = JournalRepositoryStub(journals: [journal])
        let viewModel = JournalsViewModel(repository: repository)
        viewModel.requestRename(of: journal)

        let succeeded = await viewModel.saveJournalName("  Summer Trip  ")

        #expect(succeeded)
        #expect(repository.renamedJournals == [.init(id: journal.id, name: "Summer Trip")])
        #expect(repository.journals.first?.name == "Summer Trip")
    }

    @Test("The protected Unassigned journal cannot be renamed")
    func rejectsRenamingUnassignedJournal() {
        let unassigned = makeJournal(name: "Unassigned", isSystemUnassigned: true)
        let viewModel = JournalsViewModel(repository: JournalRepositoryStub(journals: [unassigned]))

        viewModel.requestRename(of: unassigned)

        #expect(viewModel.nameEditor == nil)
    }

    private func makeJournal(
        name: String,
        memoryCount: Int = 0,
        isDefault: Bool = false,
        isSystemUnassigned: Bool = false
    ) -> JournalSummary {
        JournalSummary(
            id: UUID(),
            name: name,
            memoryCount: memoryCount,
            isDefault: isDefault,
            isSystemUnassigned: isSystemUnassigned
        )
    }
}

@MainActor
private final class JournalRepositoryStub: JournalRepository {
    struct DeletionRequest: Equatable {
        let journalID: UUID
        let strategy: JournalDeletionStrategy
    }

    var journals: [JournalSummary]
    private(set) var deletionRequests: [DeletionRequest] = []
    private(set) var createdNames: [String] = []
    private(set) var renamedJournals: [RenameRequest] = []

    struct RenameRequest: Equatable {
        let id: UUID
        let name: String
    }

    init(journals: [JournalSummary]) {
        self.journals = journals
    }

    func fetchActiveJournals() async throws -> [JournalSummary] {
        journals
    }

    func createJournal(name: String, at date: Date) throws -> Journal {
        let journal = Journal(name: name, createdAt: date, modifiedAt: date)
        createdNames.append(name)
        journals.append(
            JournalSummary(
                id: journal.id,
                name: name,
                memoryCount: 0,
                isDefault: journals.isEmpty,
                isSystemUnassigned: false
            )
        )
        return journal
    }

    func renameJournal(id: UUID, name: String, at date: Date) throws {
        guard let index = journals.firstIndex(where: { $0.id == id }) else {
            throw JournalRepositoryStubError.unavailable
        }
        renamedJournals.append(.init(id: id, name: name))
        journals[index] = JournalSummary(
            id: journals[index].id,
            name: name,
            memoryCount: journals[index].memoryCount,
            isDefault: journals[index].isDefault,
            isSystemUnassigned: journals[index].isSystemUnassigned
        )
    }

    func setDefaultJournal(id: UUID, at date: Date) throws {
        throw JournalRepositoryStubError.unavailable
    }

    func moveToRecentlyDeleted(
        journalID: UUID,
        strategy: JournalDeletionStrategy,
        at date: Date
    ) throws {
        deletionRequests.append(.init(journalID: journalID, strategy: strategy))
    }
}

private enum JournalRepositoryStubError: Error {
    case unavailable
}
