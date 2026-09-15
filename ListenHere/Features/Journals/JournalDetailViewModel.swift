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
    private(set) var deletionErrorMessage: String?
    private(set) var recoveryErrorMessage: String?
    private(set) var journalTitle = "Journal"

    var isRecentlyDeleted: Bool { access == .recentlyDeleted }
    var canEdit: Bool { access.permitsEditing }

    private let journalID: UUID
    private let access: JournalDetailAccess
    private let repository: any MemoryRepository
    private let journalRepository: (any JournalRepository)?
    private let mediaReader: (any ManagedMediaReading)?
    private let locationNameBackfiller: (any MemoryLocationNameBackfilling)?
    private let recoveryService: (any RecentlyDeletedRecovering)?
    private var managedPhotoURLs: [MemorySummary.ID: URL] = [:]
    private var locationNameBackfillTask: Task<Void, Never>?

    init(
        journalID: UUID,
        access: JournalDetailAccess = .active,
        repository: any MemoryRepository,
        journalRepository: (any JournalRepository)? = nil,
        mediaReader: (any ManagedMediaReading)? = nil,
        locationNameBackfiller: (any MemoryLocationNameBackfilling)? = nil,
        recoveryService: (any RecentlyDeletedRecovering)? = nil
    ) {
        self.journalID = journalID
        self.access = access
        self.repository = repository
        self.journalRepository = journalRepository
        self.mediaReader = mediaReader
        self.locationNameBackfiller = locationNameBackfiller
        self.recoveryService = recoveryService
    }

    func load() async {
        locationNameBackfillTask?.cancel()
        state = .loading
        do {
            let memories = try await loadMemories()
            if let journal = try await loadJournal() {
                journalTitle = journal.name
            }
            managedPhotoURLs = resolveManagedPhotoURLs(in: memories)
            state = .loaded(memories)
            if canEdit {
                startLocationNameBackfill(for: memories)
            }
        } catch is CancellationError {
            return
        } catch {
            state = .unavailable
        }
    }

    func managedPhotoURL(for memory: MemorySummary) -> URL? {
        managedPhotoURLs[memory.id]
    }

    func delete(_ memory: MemorySummary) {
        do {
            try repository.moveToRecentlyDeleted(memoryID: memory.id, at: Date())
            Task { await load() }
        } catch {
            deletionErrorMessage = "This memory couldn’t be moved to Recently Deleted."
        }
    }

    func dismissDeletionError() {
        deletionErrorMessage = nil
    }

    func recover(at date: Date = Date()) -> Bool {
        guard access == .recentlyDeleted, let recoveryService else { return false }
        do {
            try recoveryService.recover(.init(kind: .journal, modelID: journalID), at: date)
            recoveryErrorMessage = nil
            return true
        } catch {
            recoveryErrorMessage = "This journal couldn’t be recovered. Please try again."
            return false
        }
    }

    func dismissRecoveryError() {
        recoveryErrorMessage = nil
    }

    private func loadMemories() async throws -> [MemorySummary] {
        switch access {
        case .active:
            try await repository.fetchActiveMemories(journalID: journalID)
        case .recentlyDeleted:
            try await repository.fetchRecentlyDeletedMemories(journalID: journalID)
        }
    }

    private func loadJournal() async throws -> JournalSummary? {
        switch access {
        case .active:
            return try await journalRepository?.fetchActiveJournals()
                .first(where: { $0.id == journalID })
        case .recentlyDeleted:
            return try await journalRepository?.fetchRecentlyDeletedJournal(id: journalID)
        }
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

    private func startLocationNameBackfill(for memories: [MemorySummary]) {
        guard let locationNameBackfiller,
              memories.contains(where: { $0.location?.normalizedName == nil }) else {
            return
        }

        let expectedIDs = memories.map(\.id)
        locationNameBackfillTask = Task { [weak self] in
            let namedMemories = await locationNameBackfiller.resolveMissingNames(in: memories)
            guard Task.isCancelled == false,
                  let self,
                  case .loaded(let currentMemories) = state,
                  currentMemories.map(\.id) == expectedIDs else {
                return
            }
            state = .loaded(namedMemories)
        }
    }
}
