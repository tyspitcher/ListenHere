import Foundation
import SwiftData

@MainActor
final class SwiftDataMemoryRepository: MemoryRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchActiveMemories() async throws -> [MemorySummary] {
        try Task.checkCancellation()
        let memories = try modelContext.fetch(
            FetchDescriptor<Memory>(
                predicate: #Predicate { $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
            )
        )
        try Task.checkCancellation()
        return memories.map(makeSummary)
    }

    func fetchActiveMemory(id: UUID) async throws -> MemorySummary? {
        try Task.checkCancellation()
        guard let memory = try fetchMemory(id: id), memory.isRecentlyDeleted == false else {
            return nil
        }
        return makeSummary(memory)
    }

    func fetchActiveMemories(journalID: UUID) async throws -> [MemorySummary] {
        try Task.checkCancellation()
        guard let journal = try fetchJournal(id: journalID), journal.isRecentlyDeleted == false else {
            throw ListenHerePersistenceError.journalNotFound
        }
        return (journal.memories ?? [])
            .filter { $0.isRecentlyDeleted == false }
            .sorted { $0.capturedAt > $1.capturedAt }
            .map(makeSummary)
    }

    func createMemory(from draft: MemoryDraft, origin: MemoryCreationOrigin) throws -> Memory {
        do {
            do {
                try draft.validate()
            } catch let error as MemoryDraftValidationError {
                throw ListenHerePersistenceError.invalidDraft(error)
            }

            let memory = makeMemory(from: draft)
            modelContext.insert(memory)

            let journals = try journalsForCreation(draft: draft, origin: origin)
            for journal in journals {
                journal.add(memory)
            }

            try modelContext.save()
            return memory
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func updateJournalAssignments(memoryID: UUID, journalIDs: Set<UUID>) throws {
        do {
            guard let memory = try fetchMemory(id: memoryID), memory.isRecentlyDeleted == false else {
                throw ListenHerePersistenceError.memoryNotFound
            }

            let requestedJournals = try activeJournals(ids: journalIDs)
            let assignments = requestedJournals.isEmpty ? [try unassignedJournal()] : requestedJournals

            for journal in memory.journals ?? [] {
                journal.remove(memory)
            }
            for journal in assignments {
                journal.add(memory)
            }
            memory.modifiedAt = Date()
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func moveToRecentlyDeleted(memoryID: UUID, at date: Date = Date()) throws {
        do {
            guard let memory = try fetchMemory(id: memoryID), memory.isRecentlyDeleted == false else {
                throw ListenHerePersistenceError.memoryNotFound
            }
            memory.moveToRecentlyDeleted(at: date)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func makeMemory(from draft: MemoryDraft) -> Memory {
        let now = Date()
        let memory = Memory(
            id: draft.id,
            createdAt: now,
            modifiedAt: now,
            capturedAt: draft.capturedAt,
            title: draft.normalizedTitle,
            caption: draft.normalizedCaption,
            photoFilename: draft.normalizedPhotoFilename,
            audioFilename: draft.normalizedAudioFilename,
            audioDurationSeconds: draft.audioDurationSeconds
        )

        if let location = draft.location {
            memory.setLocation(
                latitude: location.latitude,
                longitude: location.longitude,
                name: location.name
            )
        }

        if let edits = draft.photoEdits {
            memory.photoEditRecipe = PhotoEditRecipe(
                filterIdentifier: edits.filterIdentifier,
                filterIntensity: edits.filterIntensity,
                cropOriginX: edits.cropOriginX,
                cropOriginY: edits.cropOriginY,
                cropWidth: edits.cropWidth,
                cropHeight: edits.cropHeight,
                rotationDegrees: edits.rotationDegrees
            )
        }

        if let edits = draft.audioEdits {
            memory.audioEditRecipe = AudioEditRecipe(
                trimStartSeconds: edits.trimStartSeconds,
                trimEndSeconds: edits.trimEndSeconds,
                isLoopingEnabled: edits.isLoopingEnabled,
                crossfadeDurationSeconds: edits.crossfadeDurationSeconds
            )
        }

        if let presentation = draft.presentation {
            memory.presentationRecipe = MemoryPresentationRecipe(
                borderStyleIdentifier: presentation.borderStyleIdentifier,
                typographyStyleIdentifier: presentation.typographyStyleIdentifier
            )
        }

        memory.decorations = draft.decorations.map {
            MemoryDecorationPlacement(
                id: $0.id,
                assetIdentifier: $0.assetIdentifier,
                normalizedX: $0.normalizedX,
                normalizedY: $0.normalizedY,
                scale: $0.scale,
                rotationDegrees: $0.rotationDegrees,
                zIndex: $0.zIndex
            )
        }
        return memory
    }

    private func journalsForCreation(
        draft: MemoryDraft,
        origin: MemoryCreationOrigin
    ) throws -> [Journal] {
        var journalIDs = draft.journalIDs
        if case .journal(let journalID) = origin {
            journalIDs.insert(journalID)
        }

        let explicitlySelected = try activeJournals(ids: journalIDs)
        if explicitlySelected.isEmpty == false {
            return explicitlySelected
        }

        return [try defaultJournal()]
    }

    private func defaultJournal() throws -> Journal {
        let active = try activeUserJournals()
        if let defaultJournal = active.first(where: \.isDefault) {
            return defaultJournal
        }
        if let first = active.first {
            first.isDefault = true
            return first
        }

        let journal = Journal(name: "Journal", isDefault: true)
        modelContext.insert(journal)
        return journal
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

    private func activeUserJournals() throws -> [Journal] {
        try modelContext.fetch(
            FetchDescriptor<Journal>(sortBy: [SortDescriptor(\.createdAt)])
        ).filter {
            $0.isRecentlyDeleted == false && $0.isSystemUnassigned == false
        }
    }

    private func activeJournals(ids: Set<UUID>) throws -> [Journal] {
        guard ids.isEmpty == false else { return [] }
        let journals = try modelContext.fetch(FetchDescriptor<Journal>())
        let pairs: [(UUID, Journal)] = journals.compactMap { journal in
            guard journal.isRecentlyDeleted == false else { return nil }
            return (journal.id, journal)
        }
        let activeByID = Dictionary<UUID, Journal>(uniqueKeysWithValues: pairs)
        let missingID = ids.first { activeByID[$0] == nil }
        guard missingID == nil else {
            throw ListenHerePersistenceError.journalNotFound
        }
        return ids.compactMap { activeByID[$0] }.sorted { $0.createdAt < $1.createdAt }
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

    private func makeSummary(_ memory: Memory) -> MemorySummary {
        MemorySummary(
            id: memory.id,
            title: memory.title.flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled Memory",
            caption: memory.caption,
            capturedAt: memory.capturedAt,
            thumbnail: memory.photoFilename.map(MemorySummary.Thumbnail.managedFile),
            hasAudio: memory.audioFilename != nil,
            audioDurationSeconds: memory.audioDurationSeconds,
            locationName: memory.locationName,
            journalNames: (memory.journals ?? [])
                .filter { $0.isRecentlyDeleted == false }
                .map(\.name)
                .sorted()
        )
    }
}
