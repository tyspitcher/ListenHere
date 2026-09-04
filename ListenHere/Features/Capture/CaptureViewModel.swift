// Owns temporary capture state, managed-media lifetime, validation, cleanup, and repository saving.

import Foundation
import Observation
import OSLog

enum CaptureState: Equatable {
    case editing
    case saving
    case saved(UUID)
    case failed(CaptureFailure)
}

enum CaptureFailure: Equatable {
    case photoImport
    case audioImport
    case mediaRemoval
    case invalidDraft
    case save
    case cleanupAfterSaveFailure

    var recoveryMessage: String {
        switch self {
        case .photoImport:
            "The photo couldn’t be added. Please try again."
        case .audioImport:
            "The recording couldn’t be added. Please try again."
        case .mediaRemoval:
            "The temporary media couldn’t be removed. Try again before leaving, or keep editing."
        case .invalidDraft:
            "Add a photo or recording before saving this memory."
        case .save:
            "The memory couldn’t be saved. Add the media again, then try again."
        case .cleanupAfterSaveFailure:
            "The memory couldn’t be saved, and its temporary media still needs to be removed."
        }
    }
}

@MainActor
@Observable
final class CaptureViewModel: Identifiable {
    let id = UUID()
    private(set) var draft: MemoryDraft
    private(set) var state: CaptureState = .editing

    var failureMessage: String? {
        guard case .failed(let failure) = state else { return nil }
        return failure.recoveryMessage
    }

    /// The capture sheet uses this to prevent an interactive dismissal that would orphan
    /// imported files. Explicit Cancel removes the files before dismissing the sheet.
    var hasUnsavedManagedMedia: Bool {
        ownedMediaFilenames.isEmpty == false
    }

    var canSave: Bool {
        draft.normalizedPhotoFilename != nil || draft.normalizedAudioFilename != nil
    }

    var hasUnsavedDraft: Bool {
        hasUnsavedManagedMedia
            || draft.normalizedTitle != nil
            || draft.normalizedCaption != nil
            || draft.location != nil
            || draft.locationCandidates.isEmpty == false
    }

    private let origin: MemoryCreationOrigin
    private let memoryRepository: any MemoryRepository
    private let mediaStore: any ManagedMediaStoring & ManagedMediaDeleting & ManagedMediaReading
    private let photoLocationExtractor: any PhotoLocationExtracting
    private let currentLocationProvider: any CurrentLocationProviding
    private let locationNameResolver: (any LocationNameResolving)?
    private var ownedMediaFilenames: Set<String> = []
    private var locationNameResolutionTasks: [String: Task<Void, Never>] = [:]
    private static let logger = Logger(
        subsystem: "com.tysonpitcher.ListenHere",
        category: "Capture"
    )

    init(
        origin: MemoryCreationOrigin,
        memoryRepository: any MemoryRepository,
        mediaStore: any ManagedMediaStoring & ManagedMediaDeleting & ManagedMediaReading,
        photoLocationExtractor: (any PhotoLocationExtracting)? = nil,
        currentLocationProvider: (any CurrentLocationProviding)? = nil,
        locationNameResolver: (any LocationNameResolving)? = nil
    ) {
        self.origin = origin
        self.draft = MemoryDraft()
        self.memoryRepository = memoryRepository
        self.mediaStore = mediaStore
        self.photoLocationExtractor = photoLocationExtractor ?? ImageIOPhotoLocationExtractor()
        self.currentLocationProvider = currentLocationProvider ?? CoreLocationCurrentLocationProvider()
        self.locationNameResolver = locationNameResolver
    }

    func updateTitle(_ title: String?) {
        guard beginEditingIfPossible() else { return }
        draft.title = title
    }

    var managedPhotoURL: URL? {
        guard let filename = draft.normalizedPhotoFilename else { return nil }
        do {
            return try mediaStore.fileURL(for: filename)
        } catch {
            Self.logger.error("Capture draft photo could not be resolved from managed storage.")
            return nil
        }
    }

    var managedAudioURL: URL? {
        guard let filename = draft.normalizedAudioFilename else { return nil }
        do {
            return try mediaStore.fileURL(for: filename)
        } catch {
            Self.logger.error("Capture draft audio could not be resolved from managed storage.")
            return nil
        }
    }

    func updateCaption(_ caption: String?) {
        guard beginEditingIfPossible() else { return }
        draft.caption = caption
    }

    func updateCapturedAt(_ capturedAt: Date) {
        guard beginEditingIfPossible() else { return }
        draft.capturedAt = capturedAt
    }

    func updateJournalIDs(_ journalIDs: Set<UUID>) {
        guard beginEditingIfPossible() else { return }
        draft.journalIDs = journalIDs
    }

    func updateLocation(_ location: MemoryDraft.Location?) {
        guard beginEditingIfPossible() else { return }
        draft.location = location
        if let location {
            appendLocationCandidate(MemoryLocationCandidate(location: location))
            resolveLocationNameIfNeeded(for: location)
        }
    }

    func captureCurrentLocationCandidate() async {
        guard beginEditingIfPossible() else { return }
        do {
            appendLocationCandidate(try await currentLocationProvider.requestCurrentLocation())
        } catch is CancellationError {
            return
        } catch {
            // Location remains optional. A denial or unavailable fix never interrupts recording.
        }
    }

    func importPhoto(_ data: Data, preferredFileExtension: String) {
        guard beginEditingIfPossible() else { return }
        guard draft.photoFilename == nil else {
            state = .failed(.mediaRemoval)
            return
        }

        do {
            let file = try mediaStore.store(
                data,
                as: .photo,
                preferredFileExtension: preferredFileExtension
            )
            draft.photoFilename = file.filename
            ownedMediaFilenames.insert(file.filename)
            if let candidate = photoLocationExtractor.locationCandidate(from: data) {
                appendLocationCandidate(candidate)
            }
        } catch {
            state = .failed(.photoImport)
        }
    }

    func reportPhotoLibraryImportFailure() {
        guard beginEditingIfPossible() else { return }
        state = .failed(.photoImport)
    }

    func reportAudioImportFailure() {
        guard beginEditingIfPossible() else { return }
        state = .failed(.audioImport)
    }

    func importAudio(
        _ data: Data,
        preferredFileExtension: String,
        durationSeconds: Double? = nil
    ) {
        guard beginEditingIfPossible() else { return }
        guard draft.audioFilename == nil else {
            state = .failed(.mediaRemoval)
            return
        }

        do {
            let file = try mediaStore.store(
                data,
                as: .audio,
                preferredFileExtension: preferredFileExtension
            )
            draft.audioFilename = file.filename
            draft.audioDurationSeconds = durationSeconds
            ownedMediaFilenames.insert(file.filename)
        } catch {
            state = .failed(.audioImport)
        }
    }

    func removePhoto() {
        guard beginEditingIfPossible() else { return }
        removeManagedMedia(
            filename: draft.photoFilename,
            clear: { self.draft.photoFilename = nil }
        )
    }

    func removeAudio() {
        guard beginEditingIfPossible() else { return }
        removeManagedMedia(
            filename: draft.audioFilename,
            clear: {
                self.draft.audioFilename = nil
                self.draft.audioDurationSeconds = nil
            }
        )
    }

    func save() {
        guard case .editing = state else { return }

        do {
            try draft.validate()
        } catch {
            state = .failed(.invalidDraft)
            return
        }

        state = .saving
        do {
            let memory = try memoryRepository.createMemory(from: draft, origin: origin)
            ownedMediaFilenames.removeAll()
            state = .saved(memory.id)
        } catch {
            handleSaveFailure()
        }
    }

    /// Call this before dismissing an unfinished capture flow so imported files do not outlive its draft.
    @discardableResult
    func discardDraft() -> Bool {
        guard beginEditingIfPossible() else { return false }
        do {
            try deleteOwnedMedia()
            resetDraft()
            return true
        } catch {
            state = .failed(.mediaRemoval)
            return false
        }
    }

    /// Releases an unsaved draft after a cleanup retry has failed so a person can leave capture.
    /// The managed filenames are intentionally forgotten; any remaining media stays private to the
    /// app container and is not referenced by a saved memory.
    func abandonDraftAfterCleanupFailure() {
        ownedMediaFilenames.removeAll()
        resetDraft()
    }

    func acknowledgeFailure() {
        guard case .failed = state else { return }
        state = .editing
    }

    private func appendLocationCandidate(_ candidate: MemoryLocationCandidate) {
        guard candidate.location.isValid,
              draft.locationCandidates.contains(candidate) == false else {
            return
        }
        draft.locationCandidates.append(candidate)
        if draft.location == nil {
            draft.location = candidate.location
        }
        resolveLocationNameIfNeeded(for: candidate.location)
    }

    private func resolveLocationNameIfNeeded(for location: MemoryLocation) {
        guard let locationNameResolver,
              location.normalizedName == nil else {
            return
        }

        let taskID = MemoryLocationCandidate(location: location).id
        guard locationNameResolutionTasks[taskID] == nil else { return }

        locationNameResolutionTasks[taskID] = Task { [weak self] in
            defer { self?.locationNameResolutionTasks[taskID] = nil }
            do {
                guard let name = try await locationNameResolver.name(for: location) else { return }
                guard Task.isCancelled == false, let self else { return }
                self.applyResolvedLocationName(name, to: location)
            } catch {
                // Capture is intentionally independent of a Maps response. Browsing later will
                // retry unnamed saved locations when a connection becomes available.
            }
        }
    }

    private func applyResolvedLocationName(_ name: String, to location: MemoryLocation) {
        if case .saved = state { return }

        var namedLocation = location
        namedLocation.name = name
        draft.locationCandidates = draft.locationCandidates.map { candidate in
            guard candidate.location.representsSamePlace(as: location),
                  candidate.location.normalizedName == nil else {
                return candidate
            }
            return MemoryLocationCandidate(location: namedLocation)
        }
        if let selectedLocation = draft.location,
           selectedLocation.representsSamePlace(as: location),
           selectedLocation.normalizedName == nil {
            draft.location = namedLocation
        }
    }

    private func removeManagedMedia(filename: String?, clear: () -> Void) {
        guard let filename else { return }
        guard ownedMediaFilenames.contains(filename) else {
            state = .failed(.mediaRemoval)
            return
        }

        do {
            try mediaStore.deleteManagedFiles(named: [filename])
            ownedMediaFilenames.remove(filename)
            clear()
        } catch {
            state = .failed(.mediaRemoval)
        }
    }

    private func handleSaveFailure() {
        do {
            try deleteOwnedMedia()
            clearOwnedMediaReferences()
            state = .failed(.save)
        } catch {
            // Keep the draft and its tracked files intact so a cleanup retry remains possible.
            state = .failed(.cleanupAfterSaveFailure)
        }
    }

    private func deleteOwnedMedia() throws {
        guard ownedMediaFilenames.isEmpty == false else { return }
        try mediaStore.deleteManagedFiles(named: ownedMediaFilenames)
        ownedMediaFilenames.removeAll()
    }

    private func clearOwnedMediaReferences() {
        draft.photoFilename = nil
        draft.audioFilename = nil
        draft.audioDurationSeconds = nil
    }

    private func resetDraft() {
        locationNameResolutionTasks.values.forEach { $0.cancel() }
        locationNameResolutionTasks.removeAll()
        draft = MemoryDraft()
        state = .editing
    }

    private func beginEditingIfPossible() -> Bool {
        switch state {
        case .editing:
            return true
        case .failed:
            state = .editing
            return true
        case .saving, .saved:
            return false
        }
    }

#if DEBUG
    func setPreviewState(_ previewState: CaptureState) {
        state = previewState
    }
#endif
}
