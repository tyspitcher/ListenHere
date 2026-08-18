import Foundation
import Observation

enum AllMemoriesState: Equatable {
    case idle
    case loading
    case loaded([MemorySummary])
    case failed(String)
}

@MainActor
@Observable
final class AllMemoriesViewModel {
    private(set) var state: AllMemoriesState = .idle

    private let repository: any MemoryRepository
    private var loadTask: Task<Void, Never>?

    init(repository: any MemoryRepository) {
        self.repository = repository
    }

    func load() {
        loadTask?.cancel()
        state = .loading

        let repository = repository
        loadTask = Task { [weak self] in
            do {
                let memories = try await repository.fetchActiveMemories()
                try Task.checkCancellation()
                self?.state = .loaded(memories)
            } catch is CancellationError {
                return
            } catch {
                self?.state = .failed("Your memories couldn’t be loaded. Please try again.")
            }
        }
    }

    func delete(_ memory: MemorySummary, at date: Date = Date()) {
        do {
            try repository.moveToRecentlyDeleted(memoryID: memory.id, at: date)
            load()
        } catch {
            state = .failed("This memory couldn’t be moved to Recently Deleted.")
        }
    }
}
