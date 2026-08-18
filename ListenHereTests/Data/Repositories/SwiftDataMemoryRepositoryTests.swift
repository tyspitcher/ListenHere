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
