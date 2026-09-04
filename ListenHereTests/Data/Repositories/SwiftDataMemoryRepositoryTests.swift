import Foundation
import SwiftData
import Testing
@testable import ListenHere

struct SwiftDataMemoryRepositoryTests {
    @Test("Creating the first memory creates and assigns a default journal")
    @MainActor
    func creationCreatesDefaultJournal() throws {
        let setup = try makeSetup()
        let draft = MemoryDraft(
            capturedAt: Date(timeIntervalSince1970: 2_000),
            title: "Rain on the Porch",
            audioFilename: "audio/rain.m4a",
            audioDurationSeconds: 20
        )

        let memory = try setup.repository.createMemory(from: draft, origin: .allMemories)

        let journal = try #require(memory.journals?.first)
        #expect(journal.name == "Journal")
        #expect(journal.isDefault)
        #expect(memory.audioFilename == "audio/rain.m4a")
    }

    @Test("Explicit journal selections support multiple journals")
    @MainActor
    func creationSupportsMultipleJournals() throws {
        let setup = try makeSetup()
        let family = Journal(name: "Family", isDefault: true)
        let nature = Journal(name: "Nature")
        setup.context.insert(family)
        setup.context.insert(nature)
        try setup.context.save()
        let draft = MemoryDraft(
            photoFilename: "photos/forest.heic",
            journalIDs: [family.id, nature.id]
        )

        let memory = try setup.repository.createMemory(from: draft, origin: .allMemories)

        #expect(Set(memory.journals?.map(\.id) ?? []) == [family.id, nature.id])
    }

    @Test("Journal-scoped creation always includes the originating journal")
    @MainActor
    func creationIncludesOriginatingJournal() throws {
        let setup = try makeSetup()
        let family = Journal(name: "Family", isDefault: true)
        let music = Journal(name: "Music")
        setup.context.insert(family)
        setup.context.insert(music)
        try setup.context.save()
        let draft = MemoryDraft(
            audioFilename: "audio/concert.m4a",
            journalIDs: [family.id]
        )

        let memory = try setup.repository.createMemory(from: draft, origin: .journal(music.id))

        #expect(Set(memory.journals?.map(\.id) ?? []) == [family.id, music.id])
    }

    @Test("Non-destructive edit recipes persist with the memory")
    @MainActor
    func recipesPersist() throws {
        let setup = try makeSetup()
        let draft = MemoryDraft(
            photoFilename: "photos/beach.heic",
            audioFilename: "audio/waves.m4a",
            audioDurationSeconds: 30,
            photoEdits: .init(filterIdentifier: "warm", filterIntensity: 0.6),
            audioEdits: .init(
                trimStartSeconds: 2,
                trimEndSeconds: 18,
                isLoopingEnabled: true,
                crossfadeDurationSeconds: 1
            ),
            presentation: .init(
                borderStyleIdentifier: "instantPhoto",
                typographyStyleIdentifier: "handwrittenAccent"
            ),
            decorations: [
                .init(assetIdentifier: "leaf", normalizedX: 0.75, normalizedY: 0.2),
            ]
        )

        let memory = try setup.repository.createMemory(from: draft, origin: .allMemories)
        let fetched = try #require(
            setup.context.fetch(FetchDescriptor<Memory>()).first(where: { $0.id == memory.id })
        )

        #expect(fetched.photoFilename == "photos/beach.heic")
        #expect(fetched.photoEditRecipe?.filterIdentifier == "warm")
        #expect(fetched.audioEditRecipe?.trimEndSeconds == 18)
        #expect(fetched.presentationRecipe?.typographyStyleIdentifier == "handwrittenAccent")
        #expect(fetched.decorations?.first?.assetIdentifier == "leaf")
    }

    @Test("An invalid draft leaves no partial models")
    @MainActor
    func invalidDraftRollsBack() throws {
        let setup = try makeSetup()
        let draft = MemoryDraft(title: "Missing media")

        #expect(throws: ListenHerePersistenceError.invalidDraft(.missingMedia)) {
            try setup.repository.createMemory(from: draft, origin: .allMemories)
        }

        #expect(try setup.context.fetch(FetchDescriptor<Memory>()).isEmpty)
        #expect(try setup.context.fetch(FetchDescriptor<Journal>()).isEmpty)
    }

    @Test("Updating saved content replaces media references and metadata together")
    @MainActor
    func updateContentPersistsOneSnapshot() throws {
        let setup = try makeSetup()
        let memory = try setup.repository.createMemory(
            from: MemoryDraft(
                capturedAt: Date(timeIntervalSince1970: 1_000),
                title: "Original",
                photoFilename: "photos/original.heic",
                audioFilename: "audio/original.m4a",
                audioDurationSeconds: 8
            ),
            origin: .allMemories
        )
        let newDate = Date(timeIntervalSince1970: 2_000)

        try setup.repository.updateMemoryContent(
            id: memory.id,
            update: MemoryContentUpdate(
                title: "  Updated  ",
                caption: "  New description  ",
                capturedAt: newDate,
                photoFilename: nil,
                audioFilename: "audio/replacement.m4a",
                audioDurationSeconds: 12
            )
        )

        #expect(memory.title == "Updated")
        #expect(memory.caption == "New description")
        #expect(memory.capturedAt == newDate)
        #expect(memory.photoFilename == nil)
        #expect(memory.audioFilename == "audio/replacement.m4a")
        #expect(memory.audioDurationSeconds == 12)
    }

    @Test("Location candidates and a canonical manual pin persist together")
    @MainActor
    func locationCandidatesPersist() throws {
        let setup = try makeSetup()
        let photoLocation = MemoryLocation(latitude: 47.6062, longitude: -122.3321, source: .photoMetadata)
        let deviceLocation = MemoryLocation(latitude: 47.6097, longitude: -122.3331, source: .deviceCapture)
        var draft = MemoryDraft(photoFilename: "photos/forest.heic")
        draft.location = photoLocation
        draft.locationCandidates = [
            .init(location: photoLocation),
            .init(location: deviceLocation),
        ]

        let memory = try setup.repository.createMemory(from: draft, origin: .allMemories)
        let manualLocation = MemoryLocation(latitude: 40.7608, longitude: -111.8910, source: .manualPin)
        try setup.repository.updateMemoryContent(
            id: memory.id,
            update: MemoryContentUpdate(
                title: memory.title,
                caption: memory.caption,
                capturedAt: memory.capturedAt,
                photoFilename: memory.photoFilename,
                audioFilename: memory.audioFilename,
                audioDurationSeconds: memory.audioDurationSeconds,
                location: manualLocation,
                shouldUpdateLocation: true,
                locationCandidates: [
                    .init(location: photoLocation),
                    .init(location: deviceLocation),
                    .init(location: manualLocation),
                ]
            )
        )

        #expect(memory.location == manualLocation)
        #expect(memory.locationCandidates.map(\.location) == [photoLocation, deviceLocation, manualLocation])
    }

    @Test("Updating saved content replaces journal assignments in the same snapshot")
    @MainActor
    func updateContentReplacesJournalAssignments() async throws {
        let setup = try makeSetup()
        let family = Journal(name: "Family", isDefault: true)
        let nature = Journal(name: "Nature")
        setup.context.insert(family)
        setup.context.insert(nature)
        try setup.context.save()
        let memory = try setup.repository.createMemory(
            from: MemoryDraft(
                photoFilename: "photos/original.heic",
                journalIDs: [family.id]
            ),
            origin: .allMemories
        )

        try setup.repository.updateMemoryContent(
            id: memory.id,
            update: MemoryContentUpdate(
                title: memory.title,
                caption: memory.caption,
                capturedAt: memory.capturedAt,
                photoFilename: memory.photoFilename,
                audioFilename: memory.audioFilename,
                audioDurationSeconds: memory.audioDurationSeconds,
                journalIDs: [family.id, nature.id]
            )
        )

        #expect(Set(memory.journals?.map(\.id) ?? []) == [family.id, nature.id])
        let summary = try #require(await setup.repository.fetchActiveMemory(id: memory.id))
        #expect(summary.journalIDs == [family.id, nature.id])
        #expect(Set(summary.journalNames) == ["Family", "Nature"])
    }

    @Test("Updating saved content refuses to remove the final medium")
    @MainActor
    func updateContentRequiresMedia() throws {
        let setup = try makeSetup()
        let memory = try setup.repository.createMemory(
            from: MemoryDraft(photoFilename: "photos/original.heic"),
            origin: .allMemories
        )

        #expect(throws: ListenHerePersistenceError.invalidDraft(.missingMedia)) {
            try setup.repository.updateMemoryContent(
                id: memory.id,
                update: MemoryContentUpdate(
                    title: nil,
                    caption: nil,
                    capturedAt: memory.capturedAt,
                    photoFilename: nil,
                    audioFilename: nil,
                    audioDurationSeconds: nil
                )
            )
        }
        #expect(memory.photoFilename == "photos/original.heic")
    }

    @MainActor
    private func makeSetup() throws -> (
        context: ModelContext,
        repository: SwiftDataMemoryRepository
    ) {
        let schema = Schema(versionedSchema: ListenHereSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: ListenHereMigrationPlan.self,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        return (context, SwiftDataMemoryRepository(modelContext: context))
    }
}
