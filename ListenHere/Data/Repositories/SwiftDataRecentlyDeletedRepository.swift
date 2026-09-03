// Implements Recently Deleted listing, recovery, permanent removal, expiry, and managed-media cleanup.

import Foundation
import SwiftData

@MainActor
final class SwiftDataRecentlyDeletedRepository: RecentlyDeletedRepository {
    private let modelContext: ModelContext
    private let mediaStore: any ManagedMediaDeleting

    init(modelContext: ModelContext, mediaStore: any ManagedMediaDeleting) {
        self.modelContext = modelContext
        self.mediaStore = mediaStore
    }

    func fetchItems() throws -> [RecentlyDeletedItem] {
        let deletedMemories = try modelContext.fetch(
            FetchDescriptor<Memory>(
                predicate: #Predicate { $0.deletedAt != nil },
                sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]
            )
        )
        let deletedJournals = try modelContext.fetch(
            FetchDescriptor<Journal>(
                predicate: #Predicate { $0.deletedAt != nil },
                sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]
            )
        )

        return (deletedMemories.compactMap(makeItem) + deletedJournals.compactMap(makeItem))
            .sorted { $0.deletedAt > $1.deletedAt }
    }

    func recover(_ itemID: RecentlyDeletedItem.ID, at date: Date) throws {
        switch itemID.kind {
        case .memory:
            guard let memory = try fetchMemory(id: itemID.modelID), memory.isRecentlyDeleted else {
                return
            }
            try recover(memory, at: date)
        case .journal:
            guard let journal = try fetchJournal(id: itemID.modelID), journal.isRecentlyDeleted else {
                return
            }
            try recover(journal, at: date)
        }

        try modelContext.save()
    }

    func permanentlyDelete(_ itemID: RecentlyDeletedItem.ID) throws {
        switch itemID.kind {
        case .memory:
            guard let memory = try fetchMemory(id: itemID.modelID), memory.isRecentlyDeleted else {
                return
            }
            try permanentlyDelete(memory)
        case .journal:
            guard let journal = try fetchJournal(id: itemID.modelID), journal.isRecentlyDeleted else {
                return
            }
            modelContext.delete(journal)
        }

        try modelContext.save()
    }

    func purgeExpiredItems(at referenceDate: Date) throws {
        let cutoff = RecentlyDeletedPolicy.cutoffDate(relativeTo: referenceDate)
        let expiredMemories = try modelContext.fetch(
            FetchDescriptor<Memory>(predicate: #Predicate { memory in
                if let deletedAt = memory.deletedAt {
                    deletedAt <= cutoff
                } else {
                    false
                }
            })
        )
        let expiredJournals = try modelContext.fetch(
            FetchDescriptor<Journal>(predicate: #Predicate { journal in
                if let deletedAt = journal.deletedAt {
                    deletedAt <= cutoff
                } else {
                    false
                }
            })
        )

        for memory in expiredMemories {
            try permanentlyDelete(memory)
        }
        for journal in expiredJournals {
            modelContext.delete(journal)
        }

        try modelContext.save()
    }

    private func recover(_ memory: Memory, at date: Date) throws {
        let deletedJournals = (memory.journals ?? []).filter(\.isRecentlyDeleted)
        for journal in deletedJournals {
            journal.remove(memory)
        }

        let activeJournals = (memory.journals ?? []).filter { $0.isRecentlyDeleted == false }
        if activeJournals.isEmpty {
            try unassignedJournal().add(memory)
        }

        memory.restoreFromRecentlyDeleted(at: date)
    }

    private func recover(_ journal: Journal, at date: Date) throws {
        let defaultJournal = try activeDefaultJournal()
        let shouldRestoreAsDefault = journal.wasDefaultBeforeDeletion && defaultJournal == nil
        journal.restoreFromRecentlyDeleted(at: date)
        journal.isDefault = shouldRestoreAsDefault
        journal.finishRestoration()
    }

    private func permanentlyDelete(_ memory: Memory) throws {
        var filenames = Set<String>()
        if let photoFilename = memory.photoFilename {
            filenames.insert(photoFilename)
        }
        if let audioFilename = memory.audioFilename {
            filenames.insert(audioFilename)
        }

        try mediaStore.deleteManagedFiles(named: filenames)
        modelContext.delete(memory)
    }

    private func unassignedJournal() throws -> Journal {
        let journals = try modelContext.fetch(FetchDescriptor<Journal>())
        if let existing = journals.first(where: {
            $0.isSystemUnassigned && $0.isRecentlyDeleted == false
        }) {
            return existing
        }

        let journal = Journal(name: "Unassigned", isSystemUnassigned: true)
        modelContext.insert(journal)
        return journal
    }

    private func activeDefaultJournal() throws -> Journal? {
        try modelContext.fetch(FetchDescriptor<Journal>()).first(where: {
            $0.isDefault && $0.isRecentlyDeleted == false
        })
    }

    private func fetchMemory(id: UUID) throws -> Memory? {
        try modelContext.fetch(
            FetchDescriptor<Memory>(predicate: #Predicate { $0.id == id })
        ).first
    }

    private func fetchJournal(id: UUID) throws -> Journal? {
        try modelContext.fetch(
            FetchDescriptor<Journal>(predicate: #Predicate { $0.id == id })
        ).first
    }

    private func makeItem(_ memory: Memory) -> RecentlyDeletedItem? {
        guard let deletedAt = memory.deletedAt else {
            return nil
        }

        let title = memory.title.flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled Memory"
        return RecentlyDeletedItem(
            id: .init(kind: .memory, modelID: memory.id),
            title: title,
            deletedAt: deletedAt,
            expiresAt: RecentlyDeletedPolicy.expirationDate(for: deletedAt)
        )
    }

    private func makeItem(_ journal: Journal) -> RecentlyDeletedItem? {
        guard let deletedAt = journal.deletedAt else {
            return nil
        }

        return RecentlyDeletedItem(
            id: .init(kind: .journal, modelID: journal.id),
            title: journal.name,
            deletedAt: deletedAt,
            expiresAt: RecentlyDeletedPolicy.expirationDate(for: deletedAt)
        )
    }
}
