// Loads and exposes the memories assigned to one journal for the journal-detail screen.

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
    private let mediaReader: (any ManagedMediaReading)?
    private var managedPhotoURLs: [MemorySummary.ID: URL] = [:]

    init(
        journalID: UUID,
        repository: any MemoryRepository,
        mediaReader: (any ManagedMediaReading)? = nil
    ) {
        self.journalID = journalID
        self.repository = repository
        self.mediaReader = mediaReader
    }

    func load() async {
        state = .loading
        do {
            let memories = try await repository.fetchActiveMemories(journalID: journalID)
            managedPhotoURLs = resolveManagedPhotoURLs(in: memories)
            state = .loaded(memories)
        } catch is CancellationError {
            return
        } catch {
            state = .unavailable
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
