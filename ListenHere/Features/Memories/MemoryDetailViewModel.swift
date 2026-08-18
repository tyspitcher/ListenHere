import Foundation
import Observation

enum MemoryDetailState: Equatable {
    case loading
    case loaded(MemorySummary)
    case unavailable
}

@MainActor
@Observable
final class MemoryDetailViewModel {
    private(set) var state: MemoryDetailState = .loading

    private let memoryID: UUID
    private let repository: any MemoryRepository

    init(memoryID: UUID, repository: any MemoryRepository) {
        self.memoryID = memoryID
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            if let memory = try await repository.fetchActiveMemory(id: memoryID) {
                state = .loaded(memory)
            } else {
                state = .unavailable
            }
        } catch is CancellationError {
            return
        } catch {
            state = .unavailable
        }
    }
}
