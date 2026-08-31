// Loads active memories, maps repository errors to UI state, and coordinates deletion intents.

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
    private let mediaReader: (any ManagedMediaReading)?
    private var loadTask: Task<Void, Never>?
    private var managedPhotoURLs: [MemorySummary.ID: URL] = [:]

    init(
        repository: any MemoryRepository,
        mediaReader: (any ManagedMediaReading)? = nil
    ) {
        self.repository = repository
        self.mediaReader = mediaReader
    }

    func load() {
        loadTask?.cancel()
        state = .loading

        let repository = repository
        loadTask = Task { [weak self] in
            do {
                let memories = try await repository.fetchActiveMemories()
                try Task.checkCancellation()
                guard let self else { return }
                managedPhotoURLs = resolveManagedPhotoURLs(in: memories)
                state = .loaded(memories)
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

    func managedPhotoURL(for memory: MemorySummary) -> URL? {
        managedPhotoURLs[memory.id]
    }

    private func resolveManagedPhotoURLs(in memories: [MemorySummary]) -> [MemorySummary.ID: URL] {
        guard let mediaReader else { return [:] }

        return Dictionary(
            uniqueKeysWithValues: memories.compactMap { memory in
                guard case .managedFile(let filename) = memory.thumbnail,
                      let url = try? mediaReader.fileURL(for: filename) else {
                    return nil
                }
                return (memory.id, url)
            }
        )
    }
}
