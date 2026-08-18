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

    init(journals: [JournalSummary]) {
        self.journals = journals
    }

    func fetchActiveJournals() async throws -> [JournalSummary] {
        journals
    }

    func createJournal(name: String, at date: Date) throws -> Journal {
        throw JournalRepositoryStubError.unavailable
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
