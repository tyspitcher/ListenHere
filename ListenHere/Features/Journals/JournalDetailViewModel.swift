import Foundation
import Observation

enum JournalDetailState: Equatable {
    case loading
    case loaded([MemorySummary])
    case unavailable
}

@MainActor
@Observable
final class JournalDetailViewModel {
    private(set) var state: JournalDetailState = .loading

    private let journalID: UUID
    private let repository: any MemoryRepository

    init(journalID: UUID, repository: any MemoryRepository) {
        self.journalID = journalID
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await repository.fetchActiveMemories(journalID: journalID))
        } catch is CancellationError {
            return
        } catch {
            state = .unavailable
        }
    }
}
