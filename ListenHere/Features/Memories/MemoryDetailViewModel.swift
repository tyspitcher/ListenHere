// Loads one active memory and exposes detail-screen loading, content, and error state.
import Foundation
import Observation

enum MemoryDetailState: Equatable {
    case loading
    case loaded(MemorySummary)
    case unavailable
}

@MainActor
@Observable
final class MemoryDetailViewModel {
    private(set) var state: MemoryDetailState = .loading
    private(set) var photoURL: URL?
    private(set) var audioPlaybackState: AudioPlaybackState = .unavailable
    private(set) var recoveryErrorMessage: String?

    var canEdit: Bool {
        access.permitsEditing && mediaEditor != nil
    }

    var isRecentlyDeleted: Bool {
        access.isRecentlyDeleted
    }

    var canRecover: Bool {
        access.isRecentlyDeleted && recoveryService != nil
    }

    private let memoryID: UUID
    private let access: MemoryDetailAccess
    private let repository: any MemoryRepository
    private let journalRepository: (any JournalRepository)?
    private let mediaStore: any ManagedMediaReading
    private let mediaEditor: (any ManagedMediaStoring & ManagedMediaDeleting & ManagedMediaReading)?
    private let recoveryService: (any RecentlyDeletedRecovering)?
    private let audioPlaybackService: any AudioPlaybackServicing
    private let locationNameBackfiller: (any MemoryLocationNameBackfilling)?
    private var playbackRefreshTask: Task<Void, Never>?
    private var locationNameBackfillTask: Task<Void, Never>?

    init(
        memoryID: UUID,
        access: MemoryDetailAccess = .active,
        repository: any MemoryRepository,
        journalRepository: (any JournalRepository)? = nil,
        mediaStore: any ManagedMediaReading,
        mediaEditor: (any ManagedMediaStoring & ManagedMediaDeleting & ManagedMediaReading)? = nil,
        recoveryService: (any RecentlyDeletedRecovering)? = nil,
        audioPlaybackService: any AudioPlaybackServicing,
        locationNameBackfiller: (any MemoryLocationNameBackfilling)? = nil
    ) {
        self.memoryID = memoryID
        self.access = access
        self.repository = repository
        self.journalRepository = journalRepository
        self.mediaStore = mediaStore
        self.mediaEditor = mediaEditor
        self.recoveryService = recoveryService
        self.audioPlaybackService = audioPlaybackService
        self.locationNameBackfiller = locationNameBackfiller
    }

    func makeEditSession(for memory: MemorySummary) -> MemoryEditSessionViewModel? {
        guard access.permitsEditing, let mediaEditor else { return nil }
        return MemoryEditSessionViewModel(
            memory: memory,
            repository: repository,
            journalRepository: journalRepository,
            mediaStore: mediaEditor
        )
    }

    func recover(at date: Date = Date()) -> Bool {
        guard canRecover, let recoveryService else { return false }

        do {
            try recoveryService.recover(
                .init(kind: .memory, modelID: memoryID),
                at: date
            )
            recoveryErrorMessage = nil
            return true
        } catch {
            recoveryErrorMessage = "This memory couldn’t be recovered. Please try again."
            return false
        }
    }

    func dismissRecoveryError() {
        recoveryErrorMessage = nil
    }

    func load() async {
        await stopPlayback()
        locationNameBackfillTask?.cancel()
        state = .loading
        photoURL = nil
        audioPlaybackState = .unavailable
        do {
            if let memory = try await loadMemory() {
                guard Task.isCancelled == false else { return }
                state = .loaded(memory)
                await loadManagedMedia(for: memory)
                if access.permitsEditing {
                    startLocationNameBackfill(for: memory)
                }
            } else {
                state = .unavailable
            }
        } catch is CancellationError {
            return
        } catch {
            state = .unavailable
        }
    }

    func togglePlayback() {
        guard case .unavailable = audioPlaybackState else {
            if audioPlaybackService.isPlaying {
                playbackRefreshTask?.cancel()
                playbackRefreshTask = nil
                audioPlaybackService.pause()
                updatePlaybackState()
                return
            }

            do {
                try audioPlaybackService.play()
                updatePlaybackState()
                startPlaybackRefresh()
            } catch {
                audioPlaybackState = .failed
            }
            return
        }
    }

    func stopPlayback() async {
        playbackRefreshTask?.cancel()
        playbackRefreshTask = nil
        await audioPlaybackService.stop()
        if case .unavailable = audioPlaybackState {
            return
        }
        audioPlaybackState = .ready(duration: currentAudioDuration)
    }

    private func loadManagedMedia(for memory: MemorySummary) async {
        if case .managedFile(let filename) = memory.thumbnail {
            photoURL = try? mediaStore.fileURL(for: filename)
        }

        guard let filename = memory.audioFilename,
              let audioURL = try? mediaStore.fileURL(for: filename) else {
            return
        }

        do {
            try await audioPlaybackService.loadAudio(at: audioURL)
            audioPlaybackState = .ready(duration: currentAudioDuration)
        } catch {
            audioPlaybackState = .unavailable
        }
    }

    private func loadMemory() async throws -> MemorySummary? {
        switch access {
        case .active:
            try await repository.fetchActiveMemory(id: memoryID)
        case .recentlyDeleted:
            try await repository.fetchRecentlyDeletedMemory(id: memoryID)
        }
    }

    private var currentAudioDuration: TimeInterval? {
        let duration = audioPlaybackService.duration
        return duration > 0 ? duration : nil
    }

    private func startPlaybackRefresh() {
        playbackRefreshTask?.cancel()
        playbackRefreshTask = Task { [weak self] in
            let clock = ContinuousClock()
            while Task.isCancelled == false {
                try? await clock.sleep(for: .milliseconds(250))
                guard Task.isCancelled == false else { return }
                guard let self else { return }
                self.refreshPlayback()
            }
        }
    }

    private func refreshPlayback() {
        guard audioPlaybackService.isPlaying else {
            playbackRefreshTask?.cancel()
            playbackRefreshTask = nil
            audioPlaybackState = .ready(duration: currentAudioDuration)
            return
        }
        updatePlaybackState()
    }

    private func updatePlaybackState() {
        let elapsed = audioPlaybackService.currentTime
        let duration = audioPlaybackService.duration
        audioPlaybackState = audioPlaybackService.isPlaying
            ? .playing(elapsed: elapsed, duration: duration)
            : .paused(elapsed: elapsed, duration: duration)
    }

    private func startLocationNameBackfill(for memory: MemorySummary) {
        guard let locationNameBackfiller,
              memory.location?.normalizedName == nil else {
            return
        }

        let expectedLocation = memory.location
        locationNameBackfillTask = Task { [weak self] in
            let namedMemory = await locationNameBackfiller.resolveMissingNames(in: [memory]).first
            guard Task.isCancelled == false,
                  let self,
                  let namedMemory,
                  case .loaded(let currentMemory) = state,
                  currentMemory.id == memory.id,
                  currentMemory.location == expectedLocation else {
                return
            }
            state = .loaded(namedMemory)
        }
    }
}
