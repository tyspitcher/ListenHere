import Foundation
import Testing
@testable import ListenHere

@MainActor
struct CaptureMediaPreviewViewModelTests {
    @Test("The composer resolves draft media and extracts a waveform")
    func loadsDraftAudioAndWaveform() async {
        let mediaStore = InMemoryManagedMediaStore()
        let captureViewModel = makeCaptureViewModel(mediaStore: mediaStore)
        captureViewModel.importAudio(
            Data("audio".utf8),
            preferredFileExtension: "m4a",
            durationSeconds: 12
        )
        let playbackService = CapturePlaybackServiceStub(duration: 12)
        let viewModel = AudioPreviewViewModel(
            audioURL: { captureViewModel.managedAudioURL },
            fallbackDuration: { captureViewModel.draft.audioDurationSeconds },
            audioPlaybackService: playbackService,
            waveformAnalyzer: WaveformAnalyzerStub(samples: [0.2, 0.8])
        )

        await viewModel.loadAudio()

        #expect(viewModel.audioPlaybackState == .ready(duration: 12))
        #expect(viewModel.waveformSamples == [0.2, 0.8])
        #expect(playbackService.loadedURL == URL(filePath: "/in-memory/audio/test-1.m4a"))
    }

    @Test("Playback remains available when waveform extraction fails")
    func waveformFailureFallsBackToPlayback() async {
        let mediaStore = InMemoryManagedMediaStore()
        let captureViewModel = makeCaptureViewModel(mediaStore: mediaStore)
        captureViewModel.importAudio(
            Data("audio".utf8),
            preferredFileExtension: "m4a",
            durationSeconds: 12
        )
        let viewModel = AudioPreviewViewModel(
            audioURL: { captureViewModel.managedAudioURL },
            fallbackDuration: { captureViewModel.draft.audioDurationSeconds },
            audioPlaybackService: CapturePlaybackServiceStub(duration: 12),
            waveformAnalyzer: WaveformAnalyzerStub(error: CaptureMediaPreviewTestError.unavailable)
        )

        await viewModel.loadAudio()

        #expect(viewModel.audioPlaybackState == .ready(duration: 12))
        #expect(viewModel.waveformSamples.isEmpty)
    }

    @Test("Removing audio cancels playback and clears preview state")
    func resetClearsPlaybackAndWaveform() async {
        let mediaStore = InMemoryManagedMediaStore()
        let captureViewModel = makeCaptureViewModel(mediaStore: mediaStore)
        captureViewModel.importAudio(
            Data("audio".utf8),
            preferredFileExtension: "m4a",
            durationSeconds: 12
        )
        let playbackService = CapturePlaybackServiceStub(duration: 12)
        let viewModel = AudioPreviewViewModel(
            audioURL: { captureViewModel.managedAudioURL },
            fallbackDuration: { captureViewModel.draft.audioDurationSeconds },
            audioPlaybackService: playbackService,
            waveformAnalyzer: WaveformAnalyzerStub(samples: [0.5])
        )
        await viewModel.loadAudio()
        viewModel.togglePlayback()

        await viewModel.resetAudio()

        #expect(playbackService.stopCount == 2)
        #expect(viewModel.audioPlaybackState == .unavailable)
        #expect(viewModel.waveformSamples.isEmpty)
    }

    @Test("Seeking updates the preview position and preserves playback state")
    func seekingUpdatesPreviewPosition() async {
        let mediaStore = InMemoryManagedMediaStore()
        let captureViewModel = makeCaptureViewModel(mediaStore: mediaStore)
        captureViewModel.importAudio(
            Data("audio".utf8),
            preferredFileExtension: "m4a",
            durationSeconds: 20
        )
        let playbackService = CapturePlaybackServiceStub(duration: 20)
        let viewModel = AudioPreviewViewModel(
            audioURL: { captureViewModel.managedAudioURL },
            fallbackDuration: { captureViewModel.draft.audioDurationSeconds },
            audioPlaybackService: playbackService,
            waveformAnalyzer: WaveformAnalyzerStub()
        )
        await viewModel.loadAudio()

        viewModel.seek(to: 0.75)

        #expect(playbackService.currentTime == 15)
        #expect(playbackService.isPlaying == false)
        #expect(viewModel.audioPlaybackState == .paused(elapsed: 15, duration: 20))

        viewModel.togglePlayback()
        viewModel.seek(to: 0.25)

        #expect(playbackService.currentTime == 5)
        #expect(playbackService.isPlaying)
        #expect(viewModel.audioPlaybackState == .playing(elapsed: 5, duration: 20))
    }

    private func makeCaptureViewModel(
        mediaStore: InMemoryManagedMediaStore
    ) -> CaptureViewModel {
        CaptureViewModel(
            origin: .allMemories,
            memoryRepository: CaptureMediaPreviewRepositoryStub(),
            mediaStore: mediaStore
        )
    }
}

@MainActor
private final class CaptureMediaPreviewRepositoryStub: MemoryRepository {
    func fetchActiveMemories() async throws -> [MemorySummary] { [] }
    func fetchActiveMemories(journalID: UUID) async throws -> [MemorySummary] { [] }
    func fetchActiveMemory(id: UUID) async throws -> MemorySummary? { nil }
    func createMemory(from draft: MemoryDraft, origin: MemoryCreationOrigin) throws -> Memory {
        throw CaptureMediaPreviewTestError.unavailable
    }
    func updateJournalAssignments(memoryID: UUID, journalIDs: Set<UUID>) throws {
        throw CaptureMediaPreviewTestError.unavailable
    }
    func moveToRecentlyDeleted(memoryID: UUID, at date: Date) throws {
        throw CaptureMediaPreviewTestError.unavailable
    }
}

@MainActor
private final class CapturePlaybackServiceStub: AudioPlaybackServicing {
    let duration: TimeInterval
    private(set) var currentTime: TimeInterval = 0
    private(set) var isPlaying = false
    private(set) var loadedURL: URL?
    private(set) var stopCount = 0

    init(duration: TimeInterval) {
        self.duration = duration
    }

    func loadAudio(at url: URL) async throws {
        loadedURL = url
        currentTime = 0
    }

    func play() throws {
        guard loadedURL != nil else { throw CaptureMediaPreviewTestError.unavailable }
        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func seek(to time: TimeInterval) {
        currentTime = min(max(0, time), duration)
    }

    func stop() async {
        stopCount += 1
        currentTime = 0
        isPlaying = false
    }
}

private struct WaveformAnalyzerStub: AudioWaveformAnalyzing {
    let samples: [Double]
    let error: (any Error)?

    init(samples: [Double] = [], error: (any Error)? = nil) {
        self.samples = samples
        self.error = error
    }

    nonisolated func samples(for url: URL, targetCount: Int) async throws -> [Double] {
        if let error { throw error }
        return samples
    }
}

private enum CaptureMediaPreviewTestError: Error {
    case unavailable
}
