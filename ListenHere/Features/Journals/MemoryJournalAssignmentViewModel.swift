// Loads active journals and commits the journal-membership change for one saved memory.

import Foundation
import Observation

@MainActor
@Observable
final class MemoryJournalAssignmentViewModel: Identifiable {
    enum State: Equatable {
        case loading
        case loaded
        case failed
    }

    let id = UUID()
    private(set) var state: State = .loading
    private(set) var journals: [JournalSummary] = []
    let selectedJournalIDs: Set<UUID>

    private let memoryID: UUID
    private let memoryRepository: any MemoryRepository
    private let journalRepository: any JournalRepository

    init(
        memory: MemorySummary,
        memoryRepository: any MemoryRepository,
        journalRepository: any JournalRepository
    ) {
        memoryID = memory.id
        selectedJournalIDs = memory.journalIDs
        self.memoryRepository = memoryRepository
        self.journalRepository = journalRepository
    }

    func load() async {
        state = .loading
        do {
            journals = try await journalRepository.fetchActiveJournals()
                .filter { $0.isSystemUnassigned == false }
            state = .loaded
        } catch is CancellationError {
            return
        } catch {
            state = .failed
        }
    }

    func applySelection(_ journalIDs: Set<UUID>) -> Bool {
        let selectableIDs = Set(journals.map(\.id))
        guard journalIDs.isEmpty == false, journalIDs.isSubset(of: selectableIDs) else {
            return false
        }

        do {
            try memoryRepository.updateJournalAssignments(memoryID: memoryID, journalIDs: journalIDs)
            return true
        } catch {
            return false
        }
    }

    func createJournal(_ rawName: String) async -> JournalSummary? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else { return nil }

        do {
            let created = try journalRepository.createJournal(name: name, at: Date())
            journals = try await journalRepository.fetchActiveJournals()
                .filter { $0.isSystemUnassigned == false }
            return journals.first(where: { $0.id == created.id })
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }
    }
}
