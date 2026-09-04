// Stages replacement media and commits one saved-memory content snapshot.

import Foundation
import Observation

@MainActor
@Observable
final class MemoryEditSessionViewModel: Identifiable {
    enum JournalState: Equatable {
        case unavailable
        case idle
        case loading
        case loaded
        case failed
    }

    let id = UUID()
    let memoryID: UUID
    var title: String
    var caption: String
    var capturedAt: Date
    private(set) var location: MemoryLocation?
    private(set) var locationCandidates: [MemoryLocationCandidate]
    private(set) var photoFilename: String?
    private(set) var photoURL: URL?
    private(set) var audioFilename: String?
    private(set) var audioDurationSeconds: Double?
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var journalState: JournalState
    private(set) var availableJournals: [JournalSummary] = []
    private(set) var selectedJournalIDs: Set<UUID>

    var hasPhoto: Bool { photoFilename != nil }
    var hasAudio: Bool { audioFilename != nil }
    var canSave: Bool { (hasPhoto || hasAudio) && isSaving == false }
    var hasStagedMedia: Bool { stagedFilenames.isEmpty == false }
    var supportsJournalEditing: Bool { journalState != .unavailable }
    var journalSelectionDescription: String {
        let loadedNames = availableJournals
            .filter { selectedJournalIDs.contains($0.id) }
            .map(\.name)
        let names = loadedNames.isEmpty ? originalJournalNames : loadedNames
        return names.isEmpty ? "No Journal" : names.formatted(.list(type: .and))
    }

    private let originalPhotoFilename: String?
    private let originalAudioFilename: String?
    private let repository: any MemoryRepository
    private let journalRepository: (any JournalRepository)?
    private let mediaStore: any ManagedMediaStoring & ManagedMediaDeleting & ManagedMediaReading
    private var stagedFilenames: Set<String> = []
    private let originalJournalNames: [String]
    private var journalSelectionWasEdited = false
    private var locationWasEdited = false

    init(
        memory: MemorySummary,
        repository: any MemoryRepository,
        journalRepository: (any JournalRepository)? = nil,
        mediaStore: any ManagedMediaStoring & ManagedMediaDeleting & ManagedMediaReading
    ) {
        memoryID = memory.id
        title = memory.title == "Untitled Memory" ? "" : memory.title
        caption = memory.caption ?? ""
        capturedAt = memory.capturedAt
        location = memory.location
        locationCandidates = memory.locationCandidates
        if case .managedFile(let filename) = memory.thumbnail {
            photoFilename = filename
            originalPhotoFilename = filename
            photoURL = try? mediaStore.fileURL(for: filename)
        } else {
            photoFilename = nil
            originalPhotoFilename = nil
            photoURL = nil
        }
        audioFilename = memory.audioFilename
        originalAudioFilename = memory.audioFilename
        audioDurationSeconds = memory.audioDurationSeconds
        selectedJournalIDs = memory.journalIDs
        originalJournalNames = memory.journalNames
        journalState = journalRepository == nil ? .unavailable : .idle
        self.repository = repository
        self.journalRepository = journalRepository
        self.mediaStore = mediaStore
    }

    func loadJournals() async {
        guard let journalRepository,
              journalState != .loading,
              journalState != .loaded else {
            return
        }
        journalState = .loading
        do {
            availableJournals = try await journalRepository.fetchActiveJournals()
                .filter { $0.isSystemUnassigned == false }
            journalState = .loaded
        } catch is CancellationError {
            journalState = .idle
        } catch {
            journalState = .failed
        }
    }

    func updateJournalSelection(_ journalIDs: Set<UUID>) {
        guard journalIDs.isEmpty == false else { return }
        let selectableIDs = Set(availableJournals.map(\.id))
        guard journalIDs.isSubset(of: selectableIDs) else { return }
        selectedJournalIDs = journalIDs
        journalSelectionWasEdited = true
    }

    func createJournal(_ rawName: String) async -> JournalSummary? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let journalRepository, name.isEmpty == false else { return nil }

        do {
            let created = try journalRepository.createJournal(name: name, at: Date())
            availableJournals = try await journalRepository.fetchActiveJournals()
                .filter { $0.isSystemUnassigned == false }
            return availableJournals.first(where: { $0.id == created.id })
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }
    }

    func updateLocation(_ location: MemoryLocation?) {
        self.location = location
        if let location {
            let candidate = MemoryLocationCandidate(location: location)
            if locationCandidates.contains(candidate) == false {
                locationCandidates.append(candidate)
            }
        }
        locationWasEdited = true
    }

    func replacePhoto(_ data: Data, fileExtension: String) {
        replace(data, kind: .photo, fileExtension: fileExtension) { file in
            photoFilename = file.filename
            photoURL = try? mediaStore.fileURL(for: file.filename)
        }
    }

    func replaceAudio(_ data: Data, fileExtension: String, duration: Double? = nil) {
        replace(data, kind: .audio, fileExtension: fileExtension) { file in
            audioFilename = file.filename
            audioDurationSeconds = duration
        }
    }

    func removePhoto() {
        do {
            try deleteStagedFileIfNeeded(photoFilename)
            photoFilename = nil
            photoURL = nil
        } catch {
            reportCleanupFailure()
        }
    }

    func removeAudio() {
        do {
            try deleteStagedFileIfNeeded(audioFilename)
            audioFilename = nil
            audioDurationSeconds = nil
        } catch {
            reportCleanupFailure()
        }
    }

    func reportImportFailure() {
        errorMessage = "The replacement media couldn’t be added. Try again."
    }

    func dismissError() { errorMessage = nil }

    func save() -> Bool {
        guard canSave else {
            errorMessage = "A memory must keep at least one photo or sound."
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try repository.updateMemoryContent(
                id: memoryID,
                update: MemoryContentUpdate(
                    title: title,
                    caption: caption,
                    capturedAt: capturedAt,
                    photoFilename: photoFilename,
                    audioFilename: audioFilename,
                    audioDurationSeconds: audioDurationSeconds,
                    journalIDs: journalSelectionWasEdited ? selectedJournalIDs : nil,
                    location: location,
                    shouldUpdateLocation: locationWasEdited,
                    locationCandidates: locationWasEdited ? locationCandidates : nil
                )
            )
            stagedFilenames.removeAll()
            let obsolete = Set([originalPhotoFilename, originalAudioFilename].compactMap { $0 })
                .subtracting([photoFilename, audioFilename].compactMap { $0 })
            try? mediaStore.deleteManagedFiles(named: obsolete)
            return true
        } catch {
            errorMessage = "The memory couldn’t be updated. Your original media is unchanged."
            return false
        }
    }

    @discardableResult
    func cancel() -> Bool {
        do {
            try mediaStore.deleteManagedFiles(named: stagedFilenames)
            stagedFilenames.removeAll()
            return true
        } catch {
            reportCleanupFailure()
            return false
        }
    }

    private func replace(
        _ data: Data,
        kind: ManagedMediaKind,
        fileExtension: String,
        apply: (ManagedMediaFile) -> Void
    ) {
        do {
            let file = try mediaStore.store(data, as: kind, preferredFileExtension: fileExtension)
            let previous = kind == .photo ? photoFilename : audioFilename
            do {
                try deleteStagedFileIfNeeded(previous)
            } catch {
                try? mediaStore.deleteManagedFiles(named: [file.filename])
                throw error
            }
            stagedFilenames.insert(file.filename)
            apply(file)
            errorMessage = nil
        } catch {
            reportImportFailure()
        }
    }

    private func deleteStagedFileIfNeeded(_ filename: String?) throws {
        guard let filename, stagedFilenames.contains(filename) else { return }
        try mediaStore.deleteManagedFiles(named: [filename])
        stagedFilenames.remove(filename)
    }

    private func reportCleanupFailure() {
        errorMessage = "Temporary replacement media couldn’t be removed. Try again before leaving."
    }
}
