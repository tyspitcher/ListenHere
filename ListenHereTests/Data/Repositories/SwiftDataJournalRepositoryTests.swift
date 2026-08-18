import Foundation
import SwiftData
import Testing
@testable import ListenHere

struct SwiftDataJournalRepositoryTests {
    @Test("The first created journal becomes the only default")
    @MainActor
    func firstJournalBecomesDefault() throws {
        let setup = try makeSetup()

        let first = try setup.repository.createJournal(name: "Everyday", at: .init(timeIntervalSince1970: 1))
        let second = try setup.repository.createJournal(name: "Family", at: .init(timeIntervalSince1970: 2))

        #expect(first.isDefault)
        #expect(second.isDefault == false)
    }

    @Test("Changing the default leaves exactly one default journal")
    @MainActor
    func changingDefaultIsExclusive() throws {
        let setup = try makeSetup()
        let first = try setup.repository.createJournal(name: "Everyday", at: .init(timeIntervalSince1970: 1))
        let second = try setup.repository.createJournal(name: "Family", at: .init(timeIntervalSince1970: 2))

        try setup.repository.setDefaultJournal(id: second.id, at: .init(timeIntervalSince1970: 3))

        #expect(first.isDefault == false)
        #expect(second.isDefault)
    }

    @Test("Deleting a journal alone moves its memories to the selected journal")
    @MainActor
    func deletionMovesMemoriesToSelectedJournal() throws {
        let setup = try makeSetup()
        let journal = try setup.repository.createJournal(name: "Trip", at: .init(timeIntervalSince1970: 1))
        let destination = try setup.repository.createJournal(
            name: "Everyday",
            at: .init(timeIntervalSince1970: 2)
        )
        let memory = Memory(capturedAt: .init(timeIntervalSince1970: 2), photoFilename: "photo.heic")
        setup.context.insert(memory)
        journal.add(memory)
        try setup.context.save()

        try setup.repository.moveToRecentlyDeleted(
            journalID: journal.id,
            strategy: .moveMemories(toJournalID: destination.id),
            at: .init(timeIntervalSince1970: 3)
        )

        #expect(journal.isRecentlyDeleted)
        #expect(memory.isRecentlyDeleted == false)
        #expect(memory.journals?.contains(where: { $0.id == destination.id }) == true)
        #expect(memory.journals?.contains(where: { $0.id == journal.id }) == true)
        #expect(destination.isDefault)
    }

    @Test("Moving memories keeps their other journal memberships without duplication")
    @MainActor
    func deletionPreservesOtherMemberships() throws {
        let setup = try makeSetup()
        let source = try setup.repository.createJournal(name: "Trip", at: .init(timeIntervalSince1970: 1))
        let destination = try setup.repository.createJournal(name: "Everyday", at: .init(timeIntervalSince1970: 2))
        let other = try setup.repository.createJournal(name: "Family", at: .init(timeIntervalSince1970: 3))
        let memory = Memory(capturedAt: .init(timeIntervalSince1970: 4), photoFilename: "photo.heic")
        setup.context.insert(memory)
        source.add(memory)
        destination.add(memory)
        other.add(memory)
        try setup.context.save()

        try setup.repository.moveToRecentlyDeleted(
            journalID: source.id,
            strategy: .moveMemories(toJournalID: destination.id),
            at: .init(timeIntervalSince1970: 5)
        )

        let journalIDs = memory.journals?.map(\.id) ?? []
        #expect(journalIDs.filter { $0 == destination.id }.count == 1)
        #expect(journalIDs.contains(other.id))
        #expect(memory.isRecentlyDeleted == false)
    }

    @Test("A journal cannot be its own move destination")
    @MainActor
    func deletionRejectsSourceAsDestination() throws {
        let setup = try makeSetup()
        let journal = try setup.repository.createJournal(name: "Trip")

        #expect(throws: ListenHerePersistenceError.invalidJournalDestination) {
            try setup.repository.moveToRecentlyDeleted(
                journalID: journal.id,
                strategy: .moveMemories(toJournalID: journal.id),
                at: .init(timeIntervalSince1970: 3)
            )
        }
        #expect(journal.isRecentlyDeleted == false)
    }

    @Test("A deleted journal cannot receive moved memories")
    @MainActor
    func deletionRejectsDeletedDestination() throws {
        let setup = try makeSetup()
        let source = try setup.repository.createJournal(name: "Trip")
        let destination = try setup.repository.createJournal(name: "Archive")
        destination.moveToRecentlyDeleted()
        try setup.context.save()

        #expect(throws: ListenHerePersistenceError.invalidJournalDestination) {
            try setup.repository.moveToRecentlyDeleted(
                journalID: source.id,
                strategy: .moveMemories(toJournalID: destination.id),
                at: .init(timeIntervalSince1970: 3)
            )
        }
        #expect(source.isRecentlyDeleted == false)
    }

    @Test("Deleting a journal and its memories uses one restoration batch")
    @MainActor
    func deletionCanMoveContainedMemories() throws {
        let setup = try makeSetup()
        let journal = try setup.repository.createJournal(name: "Trip", at: .init(timeIntervalSince1970: 1))
        let memory = Memory(capturedAt: .init(timeIntervalSince1970: 2), photoFilename: "photo.heic")
        setup.context.insert(memory)
        journal.add(memory)
        try setup.context.save()

        try setup.repository.moveToRecentlyDeleted(
            journalID: journal.id,
            strategy: .moveContainedMemoriesToRecentlyDeleted,
            at: .init(timeIntervalSince1970: 3)
        )

        #expect(journal.isRecentlyDeleted)
        #expect(memory.isRecentlyDeleted)
        #expect(journal.deletionBatchID == memory.deletionBatchID)
    }

    @Test("Deleting a journal and its memories also deletes memories shared elsewhere")
    @MainActor
    func deletionIncludesSharedMemories() throws {
        let setup = try makeSetup()
        let source = try setup.repository.createJournal(name: "Trip")
        let other = try setup.repository.createJournal(name: "Family")
        let memory = Memory(capturedAt: .init(timeIntervalSince1970: 2), photoFilename: "photo.heic")
        setup.context.insert(memory)
        source.add(memory)
        other.add(memory)
        try setup.context.save()

        try setup.repository.moveToRecentlyDeleted(
            journalID: source.id,
            strategy: .moveContainedMemoriesToRecentlyDeleted,
            at: .init(timeIntervalSince1970: 3)
        )

        #expect(memory.isRecentlyDeleted)
        #expect(memory.journals?.contains(where: { $0.id == other.id }) == true)
    }

    @MainActor
    private func makeSetup() throws -> (
        context: ModelContext,
        repository: SwiftDataJournalRepository
    ) {
        let schema = Schema(versionedSchema: ListenHereSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: ListenHereMigrationPlan.self,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        return (context, SwiftDataJournalRepository(modelContext: context))
    }
}
