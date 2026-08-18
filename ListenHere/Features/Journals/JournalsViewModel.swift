import Foundation
import Observation

enum JournalsState: Equatable {
    case loading
    case loaded([JournalSummary])
    case failed(String)
}

struct JournalMoveRequest: Identifiable, Equatable {
    let journal: JournalSummary
    let destinations: [JournalSummary]

    var id: UUID { journal.id }
}

@MainActor
@Observable
final class JournalsViewModel {
    private(set) var state: JournalsState = .loading
    private(set) var journalPendingDeletion: JournalSummary?
    private(set) var moveRequest: JournalMoveRequest?
    private(set) var errorMessage: String?
    private(set) var isPerformingDeletion = false
    private let repository: any JournalRepository

    init(repository: any JournalRepository) {
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await repository.fetchActiveJournals())
        } catch is CancellationError {
            return
        } catch {
            state = .failed("Your journals couldn’t be loaded.")
        }
    }

    func requestDeletion(of journal: JournalSummary) {
        guard journal.isSystemUnassigned == false else { return }
        journalPendingDeletion = journal
    }

    func cancelDeletion() {
        journalPendingDeletion = nil
    }

    func prepareToMoveMemories() {
        guard let journal = journalPendingDeletion else { return }
        let destinations = activeJournals.filter {
            $0.id != journal.id && $0.isSystemUnassigned == false
        }
        .sorted { first, second in
            if first.isDefault != second.isDefault {
                return first.isDefault
            }
            return first.name.localizedStandardCompare(second.name) == .orderedAscending
        }

        journalPendingDeletion = nil
        moveRequest = JournalMoveRequest(journal: journal, destinations: destinations)
    }

    func dismissMoveRequest() {
        moveRequest = nil
    }

    @discardableResult
    func moveMemoriesAndDeleteJournal(destinationID: UUID) async -> Bool {
        guard let request = moveRequest,
              request.destinations.contains(where: { $0.id == destinationID }) else {
            errorMessage = "Choose another journal before continuing."
            return false
        }

        return await delete(
            request.journal,
            strategy: .moveMemories(toJournalID: destinationID)
        )
    }

    @discardableResult
    func deleteJournalAndMemories() async -> Bool {
        guard let journal = journalPendingDeletion else { return false }
        journalPendingDeletion = nil
        return await delete(journal, strategy: .moveContainedMemoriesToRecentlyDeleted)
    }

    func dismissError() {
        errorMessage = nil
    }

    private var activeJournals: [JournalSummary] {
        guard case .loaded(let journals) = state else { return [] }
        return journals
    }

    private func delete(
        _ journal: JournalSummary,
        strategy: JournalDeletionStrategy
    ) async -> Bool {
        isPerformingDeletion = true
        defer { isPerformingDeletion = false }

        do {
            try repository.moveToRecentlyDeleted(
                journalID: journal.id,
                strategy: strategy,
                at: Date()
            )
            moveRequest = nil
            state = .loaded(try await repository.fetchActiveJournals())
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = "This journal couldn’t be deleted. Try again."
            return false
        }
    }
}
