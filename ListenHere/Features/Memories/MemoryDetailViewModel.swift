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

    private let memoryID: UUID
    private let repository: any MemoryRepository
    private let journalRepository: (any JournalRepository)?
    private let mediaStore: any ManagedMediaReading
    private let mediaEditor: (any ManagedMediaStoring & ManagedMediaDeleting & ManagedMediaReading)?
    private let audioPlaybackService: any AudioPlaybackServicing
    private var playbackRefreshTask: Task<Void, Never>?

    init(
        memoryID: UUID,
        repository: any MemoryRepository,
        journalRepository: (any JournalRepository)? = nil,
        mediaStore: any ManagedMediaReading,
        mediaEditor: (any ManagedMediaStoring & ManagedMediaDeleting & ManagedMediaReading)? = nil,
        audioPlaybackService: any AudioPlaybackServicing
    ) {
        self.memoryID = memoryID
        self.repository = repository
        self.journalRepository = journalRepository
        self.mediaStore = mediaStore
        self.mediaEditor = mediaEditor
        self.audioPlaybackService = audioPlaybackService
    }

    func makeEditSession(for memory: MemorySummary) -> MemoryEditSessionViewModel? {
        guard let mediaEditor else { return nil }
        return MemoryEditSessionViewModel(
            memory: memory,
            repository: repository,
            journalRepository: journalRepository,
            mediaStore: mediaEditor
        )
    }

    func load() async {
        await stopPlayback()
        state = .loading
        photoURL = nil
        audioPlaybackState = .unavailable
        do {
            if let memory = try await repository.fetchActiveMemory(id: memoryID) {
                guard Task.isCancelled == false else { return }
                state = .loaded(memory)
                await loadManagedMedia(for: memory)
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
}
