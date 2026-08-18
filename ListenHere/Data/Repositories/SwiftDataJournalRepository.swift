import Foundation
import SwiftData

@MainActor
final class SwiftDataJournalRepository: JournalRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchActiveJournals() async throws -> [JournalSummary] {
        try Task.checkCancellation()
        return try activeJournals().map { journal in
            JournalSummary(
                id: journal.id,
                name: journal.name,
                memoryCount: (journal.memories ?? []).count(where: { $0.isRecentlyDeleted == false }),
                isDefault: journal.isDefault,
                isSystemUnassigned: journal.isSystemUnassigned
            )
        }
    }

    func createJournal(name: String, at date: Date = Date()) throws -> Journal {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            throw ListenHerePersistenceError.emptyJournalName
        }

        do {
            let shouldBecomeDefault = try activeJournals().contains(where: {
                $0.isSystemUnassigned == false && $0.isDefault
            }) == false
            let journal = Journal(
                name: trimmedName,
                createdAt: date,
                modifiedAt: date,
                isDefault: shouldBecomeDefault
            )
            modelContext.insert(journal)
            try modelContext.save()
            return journal
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func setDefaultJournal(id: UUID, at date: Date = Date()) throws {
        do {
            let journals = try activeJournals()
            guard let selected = journals.first(where: { $0.id == id }) else {
                throw ListenHerePersistenceError.journalNotFound
            }
            guard selected.isSystemUnassigned == false else {
                throw ListenHerePersistenceError.protectedJournal
            }

            for journal in journals where journal.isSystemUnassigned == false {
                journal.isDefault = journal.id == id
                journal.modifiedAt = date
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func moveToRecentlyDeleted(
        journalID: UUID,
        strategy: JournalDeletionStrategy,
        at date: Date = Date()
    ) throws {
        do {
            guard let journal = try fetchJournal(id: journalID), journal.isRecentlyDeleted == false else {
                throw ListenHerePersistenceError.journalNotFound
            }
            guard journal.isSystemUnassigned == false else {
                throw ListenHerePersistenceError.protectedJournal
            }

            let batchID = UUID()
            let memories = (journal.memories ?? []).filter { $0.isRecentlyDeleted == false }

            switch strategy {
            case .moveMemories(let destinationID):
                guard destinationID != journal.id,
                      let destination = try fetchJournal(id: destinationID),
                      destination.isRecentlyDeleted == false,
                      destination.isSystemUnassigned == false else {
                    throw ListenHerePersistenceError.invalidJournalDestination
                }

                for memory in memories {
                    destination.add(memory)
                    memory.modifiedAt = date
                }
                destination.modifiedAt = date
                journal.moveToRecentlyDeleted(at: date, batchID: batchID)
                try ensureDefaultJournal(
                    excluding: journal.id,
                    preferredReplacement: journal.wasDefaultBeforeDeletion ? destination : nil,
                    at: date
                )
            case .moveContainedMemoriesToRecentlyDeleted:
                journal.moveToRecentlyDeleted(at: date, batchID: batchID)
                for memory in memories {
                    memory.moveToRecentlyDeleted(at: date, batchID: batchID)
                }
                try ensureDefaultJournal(excluding: journal.id, preferredReplacement: nil, at: date)
            }

            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func ensureDefaultJournal(
        excluding deletedID: UUID,
        preferredReplacement: Journal?,
        at date: Date
    ) throws {
        let candidates = try activeJournals().filter {
            $0.id != deletedID && $0.isSystemUnassigned == false
        }
        guard candidates.contains(where: \.isDefault) == false,
              let replacement = preferredReplacement ?? candidates.first else {
            return
        }
        replacement.isDefault = true
        replacement.modifiedAt = date
    }

    private func activeJournals() throws -> [Journal] {
        try modelContext.fetch(
            FetchDescriptor<Journal>(sortBy: [SortDescriptor(\.createdAt)])
        ).filter { $0.isRecentlyDeleted == false }
    }

    private func fetchJournal(id: UUID) throws -> Journal? {
        try modelContext.fetch(
            FetchDescriptor<Journal>(predicate: #Predicate { $0.id == id })
        ).first
    }

}
