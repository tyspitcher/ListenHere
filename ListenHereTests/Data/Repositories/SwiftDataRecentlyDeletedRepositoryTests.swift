import Foundation
import SwiftData
import Testing
@testable import ListenHere

struct SwiftDataRecentlyDeletedRepositoryTests {
    @Test("Recovering a memory restores its active journal assignment")
    @MainActor
    func recoverMemoryToIntactJournal() throws {
        let setup = try makeSetup()
        let journal = Journal(name: "Family")
        let memory = Memory(capturedAt: Date(timeIntervalSince1970: 1_000))
        setup.context.insert(journal)
        setup.context.insert(memory)
        journal.add(memory)
        memory.moveToRecentlyDeleted(at: Date(timeIntervalSince1970: 2_000))
        try setup.context.save()

        try setup.repository.recover(
            .init(kind: .memory, modelID: memory.id),
            at: Date(timeIntervalSince1970: 3_000)
        )

        #expect(memory.isRecentlyDeleted == false)
        #expect(memory.journals?.map(\.id) == [journal.id])
        #expect(try setup.context.fetch(FetchDescriptor<Journal>()).count == 1)
    }

    @Test("Recovering a memory whose journal was deleted assigns the system Unassigned journal")
    @MainActor
    func recoverMemoryToUnassignedJournal() throws {
        let setup = try makeSetup()
        let deletedJournal = Journal(name: "Trip")
        let memory = Memory(capturedAt: Date(timeIntervalSince1970: 1_000))
        setup.context.insert(deletedJournal)
        setup.context.insert(memory)
        deletedJournal.add(memory)
        deletedJournal.moveToRecentlyDeleted(at: Date(timeIntervalSince1970: 2_000))
        memory.moveToRecentlyDeleted(at: Date(timeIntervalSince1970: 2_000))
        try setup.context.save()

        try setup.repository.recover(
            .init(kind: .memory, modelID: memory.id),
            at: Date(timeIntervalSince1970: 3_000)
        )

        let journals = try setup.context.fetch(FetchDescriptor<Journal>())
        let unassigned = try #require(journals.first(where: { $0.isSystemUnassigned }))
        #expect(memory.journals?.map(\.id) == [unassigned.id])
        #expect(deletedJournal.memories?.isEmpty == true)
    }

    @Test("Items are purged at 30 days but not one second earlier")
    @MainActor
    func purgeUsesThirtyDayBoundary() throws {
        let setup = try makeSetup()
        let referenceDate = Date(timeIntervalSince1970: RecentlyDeletedPolicy.retentionInterval + 10_000)
        let expired = Memory(capturedAt: Date(timeIntervalSince1970: 1_000))
        let stillRecoverable = Memory(capturedAt: Date(timeIntervalSince1970: 2_000))
        setup.context.insert(expired)
        setup.context.insert(stillRecoverable)
        expired.moveToRecentlyDeleted(
            at: referenceDate.addingTimeInterval(-RecentlyDeletedPolicy.retentionInterval)
        )
        stillRecoverable.moveToRecentlyDeleted(
            at: referenceDate.addingTimeInterval(-RecentlyDeletedPolicy.retentionInterval + 1)
        )
        try setup.context.save()

        try setup.repository.purgeExpiredItems(at: referenceDate)

        let memories = try setup.context.fetch(FetchDescriptor<Memory>())
        #expect(memories.map(\.id) == [stillRecoverable.id])
    }

    @Test("Permanent memory deletion removes managed media and metadata")
    @MainActor
    func permanentDeletionRemovesMediaAndModel() throws {
        let setup = try makeSetup()
        let memory = Memory(
            capturedAt: Date(timeIntervalSince1970: 1_000),
            photoFilename: "photos/photo.heic",
            audioFilename: "audio/recording.m4a"
        )
        setup.context.insert(memory)
        memory.moveToRecentlyDeleted(at: Date(timeIntervalSince1970: 2_000))
        try setup.context.save()

        try setup.repository.permanentlyDelete(.init(kind: .memory, modelID: memory.id))

        #expect(setup.mediaStore.deletedFilenames == [
            Set(["photos/photo.heic", "audio/recording.m4a"])
        ])
        #expect(try setup.context.fetch(FetchDescriptor<Memory>()).isEmpty)
    }

    @MainActor
    private func makeSetup() throws -> (
        context: ModelContext,
        repository: SwiftDataRecentlyDeletedRepository,
        mediaStore: RecordingMediaStore
    ) {
        let schema = Schema(versionedSchema: ListenHereSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: ListenHereMigrationPlan.self,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        let mediaStore = RecordingMediaStore()
        return (
            context,
            SwiftDataRecentlyDeletedRepository(modelContext: context, mediaStore: mediaStore),
            mediaStore
        )
    }
}

@MainActor
private final class RecordingMediaStore: ManagedMediaDeleting {
    private(set) var deletedFilenames: [Set<String>] = []

    func deleteManagedFiles(named filenames: Set<String>) throws {
        deletedFilenames.append(filenames)
    }
}
