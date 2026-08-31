import Foundation
import Testing
@testable import ListenHere

@MainActor
struct CaptureViewModelTests {
    @Test("Importing a photo adds an app-managed filename to the draft")
    func importingPhotoUpdatesDraft() {
        let repository = CaptureMemoryRepositoryStub()
        let mediaStore = InMemoryManagedMediaStore()
        let viewModel = CaptureViewModel(
            origin: .allMemories,
            memoryRepository: repository,
            mediaStore: mediaStore
        )

        viewModel.importPhoto(Data("photo".utf8), preferredFileExtension: "heic")

        #expect(viewModel.draft.photoFilename == "photos/test-1.heic")
        #expect(mediaStore.files["photos/test-1.heic"] == Data("photo".utf8))
        #expect(viewModel.state == .editing)
        #expect(viewModel.hasUnsavedManagedMedia)
        #expect(viewModel.canSave)
        #expect(viewModel.hasUnsavedDraft)
    }

    @Test("Metadata marks a draft as edited without enabling save")
    func metadataDoesNotEnableSave() {
        let viewModel = CaptureViewModel(
            origin: .allMemories,
            memoryRepository: CaptureMemoryRepositoryStub(),
            mediaStore: InMemoryManagedMediaStore()
        )

        viewModel.updateTitle("Night Walk")

        #expect(viewModel.hasUnsavedDraft)
        #expect(viewModel.canSave == false)
    }

    @Test("Photo or sound independently enables save", arguments: [true, false])
    func mediaEnablesSave(usePhoto: Bool) {
        let viewModel = CaptureViewModel(
            origin: .allMemories,
            memoryRepository: CaptureMemoryRepositoryStub(),
            mediaStore: InMemoryManagedMediaStore()
        )

        if usePhoto {
            viewModel.importPhoto(Data("photo".utf8), preferredFileExtension: "heic")
        } else {
            viewModel.importAudio(
                Data("audio".utf8),
                preferredFileExtension: "m4a",
                durationSeconds: 12
            )
        }

        #expect(viewModel.canSave)
    }

    @Test("A PhotosPicker transfer failure becomes a user-recoverable photo import failure")
    func photoLibraryImportFailureIsRecoverable() {
        let viewModel = CaptureViewModel(
            origin: .allMemories,
            memoryRepository: CaptureMemoryRepositoryStub(),
            mediaStore: InMemoryManagedMediaStore()
        )

        viewModel.reportPhotoLibraryImportFailure()

        #expect(viewModel.state == .failed(.photoImport))
        #expect(viewModel.failureMessage == "The photo couldn’t be added. Please try again.")
    }

    @Test("Saving hands the complete draft and its creation origin to the repository")
    func savingPersistsDraft() {
        let repository = CaptureMemoryRepositoryStub()
        let mediaStore = InMemoryManagedMediaStore()
        let journalID = UUID()
        let viewModel = CaptureViewModel(
            origin: .journal(journalID),
            memoryRepository: repository,
            mediaStore: mediaStore
        )

        viewModel.updateTitle("Night Walk")
        viewModel.importAudio(
            Data("audio".utf8),
            preferredFileExtension: "m4a",
            durationSeconds: 12
        )
        viewModel.save()

        #expect(repository.createdDraft?.title == "Night Walk")
        #expect(repository.createdDraft?.audioFilename == "audio/test-1.m4a")
        #expect(repository.createdDraft?.capturedAt == viewModel.draft.capturedAt)
        #expect(repository.creationOrigin == .journal(journalID))
        #expect(viewModel.state == .saved(repository.createdMemoryID))
        #expect(mediaStore.files["audio/test-1.m4a"] == Data("audio".utf8))
    }

    @Test("A persistence failure removes imported media and keeps editable metadata")
    func saveFailureCleansUpImportedMedia() {
        let repository = CaptureMemoryRepositoryStub(createError: CaptureTestError.failed)
        let mediaStore = InMemoryManagedMediaStore()
        let viewModel = CaptureViewModel(
            origin: .allMemories,
            memoryRepository: repository,
            mediaStore: mediaStore
        )

        viewModel.updateTitle("Beach Morning")
        viewModel.importPhoto(Data("photo".utf8), preferredFileExtension: "heic")
        viewModel.save()

        #expect(viewModel.state == .failed(.save))
        #expect(viewModel.draft.title == "Beach Morning")
        #expect(viewModel.draft.photoFilename == nil)
        #expect(mediaStore.files.isEmpty)
        #expect(mediaStore.deletedFilenames == [Set(["photos/test-1.heic"])])
    }

    @Test("Saving without photo or audio reports draft validation without calling persistence")
    func missingMediaPreventsSave() {
        let repository = CaptureMemoryRepositoryStub()
        let mediaStore = InMemoryManagedMediaStore()
        let viewModel = CaptureViewModel(
            origin: .allMemories,
            memoryRepository: repository,
            mediaStore: mediaStore
        )

        viewModel.save()

        #expect(viewModel.state == .failed(.invalidDraft))
        #expect(viewModel.failureMessage == "Add a photo or recording before saving this memory.")
        #expect(repository.createdDraft == nil)
    }

    @Test("Discarding a draft removes its imported media")
    func discardingDraftCleansUpManagedMedia() {
        let repository = CaptureMemoryRepositoryStub()
        let mediaStore = InMemoryManagedMediaStore()
        let viewModel = CaptureViewModel(
            origin: .allMemories,
            memoryRepository: repository,
            mediaStore: mediaStore
        )

        viewModel.importPhoto(Data("photo".utf8), preferredFileExtension: "heic")
        viewModel.discardDraft()

        #expect(viewModel.draft.photoFilename == nil)
        #expect(viewModel.state == .editing)
        #expect(viewModel.hasUnsavedManagedMedia == false)
        #expect(mediaStore.files.isEmpty)
    }

    @Test("Removing one medium preserves the other medium and metadata")
    func removingPhotoPreservesOtherDraftContent() {
        let mediaStore = InMemoryManagedMediaStore()
        let viewModel = CaptureViewModel(
            origin: .allMemories,
            memoryRepository: CaptureMemoryRepositoryStub(),
            mediaStore: mediaStore
        )
        viewModel.updateTitle("Summer rain")
        viewModel.importPhoto(Data("photo".utf8), preferredFileExtension: "heic")
        viewModel.importAudio(Data("audio".utf8), preferredFileExtension: "m4a", durationSeconds: 8)

        viewModel.removePhoto()

        #expect(viewModel.draft.photoFilename == nil)
        #expect(viewModel.draft.audioFilename == "audio/test-2.m4a")
        #expect(viewModel.draft.title == "Summer rain")
        #expect(viewModel.canSave)
    }

    @Test("A cleanup failure retains the media reference and preview eligibility")
    func removalFailureRetainsMedia() {
        let mediaStore = InMemoryManagedMediaStore()
        let viewModel = CaptureViewModel(
            origin: .allMemories,
            memoryRepository: CaptureMemoryRepositoryStub(),
            mediaStore: mediaStore
        )
        viewModel.importAudio(Data("audio".utf8), preferredFileExtension: "m4a", durationSeconds: 8)
        mediaStore.nextError = CaptureTestError.failed

        viewModel.removeAudio()

        #expect(viewModel.state == .failed(.mediaRemoval))
        #expect(viewModel.draft.audioFilename == "audio/test-1.m4a")
        #expect(viewModel.draft.audioDurationSeconds == 8)
        #expect(viewModel.canSave)
    }

    @Test("Acknowledging a cleanup failure restores editing without discarding the draft")
    func acknowledgingRemovalFailureKeepsDraftEditable() {
        let mediaStore = InMemoryManagedMediaStore()
        let viewModel = CaptureViewModel(
            origin: .allMemories,
            memoryRepository: CaptureMemoryRepositoryStub(),
            mediaStore: mediaStore
        )
        viewModel.importPhoto(Data("photo".utf8), preferredFileExtension: "heic")
        mediaStore.nextError = CaptureTestError.failed

        viewModel.removePhoto()
        viewModel.acknowledgeFailure()

        #expect(viewModel.state == .editing)
        #expect(viewModel.draft.photoFilename == "photos/test-1.heic")
        #expect(viewModel.hasUnsavedManagedMedia)
        #expect(viewModel.canSave)
    }

    @Test("A cleanup-failed draft can be abandoned so capture can exit")
    func abandoningCleanupFailedDraftReleasesCaptureState() {
        let mediaStore = InMemoryManagedMediaStore()
        let viewModel = CaptureViewModel(
            origin: .allMemories,
            memoryRepository: CaptureMemoryRepositoryStub(),
            mediaStore: mediaStore
        )
        viewModel.importPhoto(Data("photo".utf8), preferredFileExtension: "heic")
        mediaStore.nextError = CaptureTestError.failed

        #expect(viewModel.discardDraft() == false)
        #expect(viewModel.state == .failed(.mediaRemoval))

        viewModel.abandonDraftAfterCleanupFailure()

        #expect(viewModel.state == .editing)
        #expect(viewModel.draft.photoFilename == nil)
        #expect(viewModel.hasUnsavedManagedMedia == false)
        #expect(mediaStore.files["photos/test-1.heic"] == Data("photo".utf8))
    }

    @Test("Discarding a draft removes media through the live file store")
    func discardingDraftCleansUpWithLocalStore() throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appending(path: "ListenHereCaptureStore-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let viewModel = CaptureViewModel(
            origin: .allMemories,
            memoryRepository: CaptureMemoryRepositoryStub(),
            mediaStore: LocalManagedMediaStore(rootDirectory: rootDirectory)
        )

        viewModel.importPhoto(Data("photo".utf8), preferredFileExtension: "jpeg")
        let filename = try #require(viewModel.draft.photoFilename)
        let storedURL = rootDirectory.appending(path: filename)
        #expect(FileManager.default.fileExists(atPath: storedURL.path))

        #expect(viewModel.discardDraft())
        #expect(FileManager.default.fileExists(atPath: storedURL.path) == false)
        #expect(viewModel.state == .editing)
    }
}

@MainActor
private final class CaptureMemoryRepositoryStub: MemoryRepository {
    let createdMemoryID = UUID()
    let createError: (any Error)?
    private(set) var createdDraft: MemoryDraft?
    private(set) var creationOrigin: MemoryCreationOrigin?

    init(createError: (any Error)? = nil) {
        self.createError = createError
    }

    func fetchActiveMemories() async throws -> [MemorySummary] { [] }
    func fetchActiveMemories(journalID: UUID) async throws -> [MemorySummary] { [] }
    func fetchActiveMemory(id: UUID) async throws -> MemorySummary? { nil }

    func createMemory(from draft: MemoryDraft, origin: MemoryCreationOrigin) throws -> Memory {
        createdDraft = draft
        creationOrigin = origin
        if let createError { throw createError }
        return Memory(id: createdMemoryID, capturedAt: draft.capturedAt)
    }

    func updateJournalAssignments(memoryID: UUID, journalIDs: Set<UUID>) throws {}
    func moveToRecentlyDeleted(memoryID: UUID, at date: Date) throws {}
}

private enum CaptureTestError: Error {
    case failed
}
