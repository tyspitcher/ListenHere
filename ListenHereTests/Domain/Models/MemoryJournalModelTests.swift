import Foundation
import SwiftData
import Testing
@testable import ListenHere

struct MemoryJournalModelTests {
    @Test("A memory can belong to multiple journals")
    @MainActor
    func memorySupportsMultipleJournals() throws {
        let context = try makeContext()
        let memory = Memory(capturedAt: Date(timeIntervalSince1970: 1_000))
        let family = Journal(name: "Family", isDefault: true)
        let travel = Journal(name: "Travel")

        context.insert(memory)
        context.insert(family)
        context.insert(travel)
        family.add(memory)
        travel.add(memory)
        try context.save()

        #expect(memory.journals?.count == 2)
        #expect(family.memories?.map(\.id) == [memory.id])
        #expect(travel.memories?.map(\.id) == [memory.id])
    }

    @Test("Assigning the same memory twice does not duplicate it")
    func duplicateAssignmentIsIgnored() {
        let memory = Memory(capturedAt: Date(timeIntervalSince1970: 1_000))
        let journal = Journal(name: "Everyday")

        journal.add(memory)
        journal.add(memory)

        #expect(journal.memories?.count == 1)
    }

    @Test("Moving a journal to Recently Deleted retains the journal and its relationships")
    @MainActor
    func journalMovesToRecentlyDeleted() throws {
        let context = try makeContext()
        let memory = Memory(capturedAt: Date(timeIntervalSince1970: 1_000))
        let journal = Journal(name: "Nature", isDefault: true)
        let deletionDate = Date(timeIntervalSince1970: 2_000)
        let batchID = UUID()

        context.insert(memory)
        context.insert(journal)
        journal.add(memory)
        try context.save()

        journal.moveToRecentlyDeleted(at: deletionDate, batchID: batchID)
        try context.save()

        let journals = try context.fetch(FetchDescriptor<Journal>())
        let memories = try context.fetch(FetchDescriptor<Memory>())
        #expect(journals.map(\.id) == [journal.id])
        #expect(memories.map(\.id) == [memory.id])
        #expect(journal.isRecentlyDeleted)
        #expect(journal.deletedAt == deletionDate)
        #expect(journal.deletionBatchID == batchID)
        #expect(journal.isDefault == false)
        #expect(memory.isRecentlyDeleted == false)
        #expect(memory.journals?.map(\.id) == [journal.id])
    }

    @Test("A recently deleted memory can be restored")
    func memoryCanBeRestored() {
        let memory = Memory(capturedAt: Date(timeIntervalSince1970: 1_000))
        let deletionDate = Date(timeIntervalSince1970: 2_000)
        let restoreDate = Date(timeIntervalSince1970: 3_000)
        let batchID = UUID()

        memory.moveToRecentlyDeleted(at: deletionDate, batchID: batchID)

        #expect(memory.isRecentlyDeleted)
        #expect(memory.deletionBatchID == batchID)

        memory.restoreFromRecentlyDeleted(at: restoreDate)

        #expect(memory.isRecentlyDeleted == false)
        #expect(memory.deletedAt == nil)
        #expect(memory.deletionBatchID == nil)
        #expect(memory.modifiedAt == restoreDate)
    }

    @Test("Location is stored and cleared as a complete coordinate pair")
    func locationCanBeUpdatedAndCleared() {
        let memory = Memory(capturedAt: Date(timeIntervalSince1970: 1_000))

        memory.setLocation(latitude: 40.7608, longitude: -111.8910, name: "Salt Lake City")

        #expect(memory.hasLocation)
        #expect(memory.latitude == 40.7608)
        #expect(memory.longitude == -111.8910)
        #expect(memory.locationName == "Salt Lake City")

        memory.clearLocation()

        #expect(memory.hasLocation == false)
        #expect(memory.latitude == nil)
        #expect(memory.longitude == nil)
        #expect(memory.locationName == nil)
    }

    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: ListenHereSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: ListenHereMigrationPlan.self,
            configurations: [configuration]
        )
        return ModelContext(container)
    }
}
