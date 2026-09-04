import Foundation
import Testing
@testable import ListenHere

@MainActor
struct MemoryEditSessionViewModelTests {
    @Test("Saving a replacement commits the new file before deleting the original")
    func saveReplacement() throws {
        let mediaStore = InMemoryManagedMediaStore()
        let originalPhoto = try mediaStore.store(
            Data([1]),
            as: .photo,
            preferredFileExtension: "heic"
        )
        let originalAudio = try mediaStore.store(
            Data([2]),
            as: .audio,
            preferredFileExtension: "m4a"
        )
        let repository = MemoryEditRepositoryStub()
        let session = makeSession(
            photoFilename: originalPhoto.filename,
            audioFilename: originalAudio.filename,
            repository: repository,
            mediaStore: mediaStore
        )

        session.replacePhoto(Data([3]), fileExtension: "jpeg")
        let replacement = try #require(session.photoFilename)

        #expect(session.save())
        #expect(repository.lastUpdate?.photoFilename == replacement)
        #expect(repository.lastUpdate?.audioFilename == originalAudio.filename)
        #expect(mediaStore.files[originalPhoto.filename] == nil)
        #expect(mediaStore.files[replacement] == Data([3]))
    }

    @Test("Cancelling an edit deletes staged media and leaves persistence untouched")
    func cancelReplacement() throws {
        let mediaStore = InMemoryManagedMediaStore()
        let original = try mediaStore.store(
            Data([1]),
            as: .photo,
            preferredFileExtension: "heic"
        )
        let repository = MemoryEditRepositoryStub()
        let session = makeSession(
            photoFilename: original.filename,
            repository: repository,
            mediaStore: mediaStore
        )

        session.replacePhoto(Data([4]), fileExtension: "jpeg")
        let staged = try #require(session.photoFilename)
        session.cancel()

        #expect(repository.lastUpdate == nil)
        #expect(mediaStore.files[original.filename] == Data([1]))
        #expect(mediaStore.files[staged] == nil)
    }

    @Test("The editor prevents removal of a memory's final medium")
    func finalMediumCannotBeSavedAsRemoved() throws {
        let mediaStore = InMemoryManagedMediaStore()
        let original = try mediaStore.store(
            Data([1]),
            as: .photo,
            preferredFileExtension: "heic"
        )
        let repository = MemoryEditRepositoryStub()
        let session = makeSession(
            photoFilename: original.filename,
            repository: repository,
            mediaStore: mediaStore
        )

        session.removePhoto()

        #expect(session.canSave == false)
        #expect(session.save() == false)
        #expect(repository.lastUpdate == nil)
        #expect(mediaStore.files[original.filename] == Data([1]))
    }

    @Test("A photo can be added after removing an existing photo from a sound memory")
    func addPhotoAfterRemovingExistingPhoto() throws {
        let mediaStore = InMemoryManagedMediaStore()
        let originalPhoto = try mediaStore.store(
            Data([1]),
            as: .photo,
            preferredFileExtension: "heic"
        )
        let originalAudio = try mediaStore.store(
            Data([2]),
            as: .audio,
            preferredFileExtension: "m4a"
        )
        let repository = MemoryEditRepositoryStub()
        let session = makeSession(
            photoFilename: originalPhoto.filename,
            audioFilename: originalAudio.filename,
            repository: repository,
            mediaStore: mediaStore
        )

        session.removePhoto()
        session.replacePhoto(Data([3]), fileExtension: "jpeg")
        let replacementPhoto = try #require(session.photoFilename)

        #expect(replacementPhoto != originalPhoto.filename)
        #expect(session.hasPhoto)
        #expect(session.save())
        #expect(repository.lastUpdate?.photoFilename == replacementPhoto)
        #expect(mediaStore.files[replacementPhoto] == Data([3]))
        #expect(mediaStore.files[originalPhoto.filename] == nil)
    }

    @Test("Failed cancellation keeps staged media owned so cleanup can be retried")
    func cancellationCleanupCanBeRetried() throws {
        let mediaStore = InMemoryManagedMediaStore()
        let original = try mediaStore.store(
            Data([1]),
            as: .photo,
            preferredFileExtension: "heic"
        )
        let repository = MemoryEditRepositoryStub()
        let session = makeSession(
            photoFilename: original.filename,
            repository: repository,
            mediaStore: mediaStore
        )
        session.replacePhoto(Data([5]), fileExtension: "jpeg")
        let staged = try #require(session.photoFilename)
        mediaStore.nextError = MemoryEditTestError.unavailable

        #expect(session.cancel() == false)
        #expect(session.hasStagedMedia)
        #expect(mediaStore.files[staged] == Data([5]))

        mediaStore.nextError = nil
        #expect(session.cancel())
        #expect(session.hasStagedMedia == false)
        #expect(mediaStore.files[staged] == nil)
    }

    @Test("A persistence failure preserves original and staged media for retry")
    func saveFailurePreservesMedia() throws {
        let mediaStore = InMemoryManagedMediaStore()
        let original = try mediaStore.store(
            Data([1]),
            as: .audio,
            preferredFileExtension: "m4a"
        )
        let repository = MemoryEditRepositoryStub()
        let session = makeSession(
            photoFilename: nil,
            audioFilename: original.filename,
            repository: repository,
            mediaStore: mediaStore
        )
        session.replaceAudio(Data([6]), fileExtension: "m4a", duration: 14)
        let staged = try #require(session.audioFilename)
        repository.nextError = MemoryEditTestError.unavailable

        #expect(session.save() == false)
        #expect(session.hasStagedMedia)
        #expect(mediaStore.files[original.filename] == Data([1]))
        #expect(mediaStore.files[staged] == Data([6]))
    }

    @Test("Journal loading excludes the protected Unassigned journal")
    func loadJournalsFiltersUnassigned() async throws {
        let familyID = UUID()
        let unassignedID = UUID()
        let repository = MemoryEditRepositoryStub()
        let journalRepository = MemoryEditJournalRepositoryStub(
            journals: [
                JournalSummary(
                    id: familyID,
                    name: "Family",
                    memoryCount: 1,
                    isDefault: true,
                    isSystemUnassigned: false
                ),
                JournalSummary(
                    id: unassignedID,
                    name: "Unassigned",
                    memoryCount: 0,
                    isDefault: false,
                    isSystemUnassigned: true
                ),
            ]
        )
        let session = makeSession(
            photoFilename: "photos/memory.heic",
            journalIDs: [familyID],
            journalNames: ["Family"],
            repository: repository,
            journalRepository: journalRepository,
            mediaStore: InMemoryManagedMediaStore()
        )

        await session.loadJournals()

        #expect(session.journalState == .loaded)
        #expect(session.availableJournals.map(\.id) == [familyID])
        #expect(session.selectedJournalIDs == [familyID])
        #expect(session.journalSelectionDescription == "Family")
    }

    @Test("Saving applies the staged multi-journal selection with the content update")
    func saveJournalSelection() async throws {
        let familyID = UUID()
        let natureID = UUID()
        let repository = MemoryEditRepositoryStub()
        let journalRepository = MemoryEditJournalRepositoryStub(
            journals: [
                JournalSummary(
                    id: familyID,
                    name: "Family",
                    memoryCount: 1,
                    isDefault: true,
                    isSystemUnassigned: false
                ),
                JournalSummary(
                    id: natureID,
                    name: "Nature",
                    memoryCount: 0,
                    isDefault: false,
                    isSystemUnassigned: false
                ),
            ]
        )
        let session = makeSession(
            photoFilename: "photos/memory.heic",
            journalIDs: [familyID],
            journalNames: ["Family"],
            repository: repository,
            journalRepository: journalRepository,
            mediaStore: InMemoryManagedMediaStore()
        )
        await session.loadJournals()

        session.updateJournalSelection([familyID, natureID])

        #expect(session.save())
        #expect(repository.lastUpdate?.journalIDs == [familyID, natureID])
        #expect(session.journalSelectionDescription == "Family and Nature")
    }

    @Test("An empty journal selection is rejected before persistence")
    func emptyJournalSelectionIsRejected() async throws {
        let familyID = UUID()
        let repository = MemoryEditRepositoryStub()
        let journalRepository = MemoryEditJournalRepositoryStub(
            journals: [
                JournalSummary(
                    id: familyID,
                    name: "Family",
                    memoryCount: 1,
                    isDefault: true,
                    isSystemUnassigned: false
                ),
            ]
        )
        let session = makeSession(
            photoFilename: "photos/memory.heic",
            journalIDs: [familyID],
            journalNames: ["Family"],
            repository: repository,
            journalRepository: journalRepository,
            mediaStore: InMemoryManagedMediaStore()
        )
        await session.loadJournals()

        session.updateJournalSelection([])

        #expect(session.selectedJournalIDs == [familyID])
        #expect(session.save())
        #expect(repository.lastUpdate?.journalIDs == nil)
    }

    @Test("A manual pin overrides the canonical location and preserves all candidates")
    func manualPinUpdatesLocationSnapshot() {
        let photoLocation = MemoryLocation(latitude: 47.6062, longitude: -122.3321, source: .photoMetadata)
        let manualLocation = MemoryLocation(latitude: 40.7608, longitude: -111.8910, source: .manualPin)
        let repository = MemoryEditRepositoryStub()
        let session = MemoryEditSessionViewModel(
            memory: MemorySummary(
                id: UUID(),
                title: "Memory",
                caption: nil,
                capturedAt: Date(),
                thumbnail: .managedFile("photos/memory.heic"),
                hasAudio: false,
                audioDurationSeconds: nil,
                locationName: nil,
                location: photoLocation,
                locationCandidates: [.init(location: photoLocation)],
                journalNames: []
            ),
            repository: repository,
            mediaStore: InMemoryManagedMediaStore()
        )

        session.updateLocation(manualLocation)

        #expect(session.save())
        #expect(repository.lastUpdate?.location == manualLocation)
        #expect(repository.lastUpdate?.shouldUpdateLocation == true)
        #expect(repository.lastUpdate?.locationCandidates == [
            .init(location: photoLocation),
            .init(location: manualLocation),
        ])
    }

    private func makeSession(
        photoFilename: String?,
        audioFilename: String? = nil,
        journalIDs: Set<UUID> = [],
        journalNames: [String] = [],
        repository: MemoryEditRepositoryStub,
        journalRepository: (any JournalRepository)? = nil,
        mediaStore: InMemoryManagedMediaStore
    ) -> MemoryEditSessionViewModel {
        MemoryEditSessionViewModel(
            memory: MemorySummary(
                id: UUID(),
                title: "Memory",
                caption: nil,
                capturedAt: Date(timeIntervalSince1970: 1),
                thumbnail: photoFilename.map(MemorySummary.Thumbnail.managedFile),
                hasAudio: audioFilename != nil,
                audioFilename: audioFilename,
                audioDurationSeconds: audioFilename == nil ? nil : 8,
                locationName: nil,
                journalIDs: journalIDs,
                journalNames: journalNames
            ),
            repository: repository,
            journalRepository: journalRepository,
            mediaStore: mediaStore
        )
    }
}

@MainActor
private final class MemoryEditRepositoryStub: MemoryRepository {
    private(set) var lastUpdate: MemoryContentUpdate?
    var nextError: (any Error)?

    func fetchActiveMemories() async throws -> [MemorySummary] { [] }
    func fetchActiveMemories(journalID: UUID) async throws -> [MemorySummary] { [] }
    func fetchActiveMemory(id: UUID) async throws -> MemorySummary? { nil }
    func createMemory(from draft: MemoryDraft, origin: MemoryCreationOrigin) throws -> Memory {
        throw MemoryEditTestError.unavailable
    }
    func updateMemoryContent(id: UUID, update: MemoryContentUpdate) throws {
        if let nextError { throw nextError }
        lastUpdate = update
    }
    func updateJournalAssignments(memoryID: UUID, journalIDs: Set<UUID>) throws {
        throw MemoryEditTestError.unavailable
    }
    func moveToRecentlyDeleted(memoryID: UUID, at date: Date) throws {
        throw MemoryEditTestError.unavailable
    }
}

@MainActor
private final class MemoryEditJournalRepositoryStub: JournalRepository {
    let journals: [JournalSummary]

    init(journals: [JournalSummary]) {
        self.journals = journals
    }

    func fetchActiveJournals() async throws -> [JournalSummary] { journals }
    func createJournal(name: String, at date: Date) throws -> Journal {
        throw MemoryEditTestError.unavailable
    }
    func renameJournal(id: UUID, name: String, at date: Date) throws {
        throw MemoryEditTestError.unavailable
    }
    func setDefaultJournal(id: UUID, at date: Date) throws {
        throw MemoryEditTestError.unavailable
    }
    func moveToRecentlyDeleted(
        journalID: UUID,
        strategy: JournalDeletionStrategy,
        at date: Date
    ) throws {
        throw MemoryEditTestError.unavailable
    }
}

private enum MemoryEditTestError: Error {
    case unavailable
}
