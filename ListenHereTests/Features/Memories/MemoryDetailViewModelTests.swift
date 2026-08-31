import Foundation
import Testing
@testable import ListenHere

@MainActor
struct MemoryDetailViewModelTests {
    @Test("Loading resolves managed photo and audio media for detail presentation")
    func loadingResolvesManagedMedia() async {
        let photoURL = URL(filePath: "/tmp/photos/morning.heic")
        let audioURL = URL(filePath: "/tmp/audio/morning.m4a")
        let playbackService = AudioPlaybackServiceStub(duration: 12)
        let viewModel = MemoryDetailViewModel(
            memoryID: UUID(),
            repository: MemoryDetailRepositoryStub(memory: makeMemory()),
            mediaStore: ManagedMediaReaderStub(
                urls: ["photos/morning.heic": photoURL, "audio/morning.m4a": audioURL]
            ),
            audioPlaybackService: playbackService
        )

        await viewModel.load()

        #expect(viewModel.photoURL == photoURL)
        #expect(viewModel.audioPlaybackState == .ready(duration: 12))
        #expect(playbackService.loadedURL == audioURL)
    }

    @Test("Missing managed audio remains unavailable without affecting memory details")
    func missingAudioIsUnavailable() async {
        let viewModel = MemoryDetailViewModel(
            memoryID: UUID(),
            repository: MemoryDetailRepositoryStub(memory: makeMemory()),
            mediaStore: ManagedMediaReaderStub(urls: [:]),
            audioPlaybackService: AudioPlaybackServiceStub(duration: 12)
        )

        await viewModel.load()

        #expect(viewModel.state == .loaded(makeMemory()))
        #expect(viewModel.photoURL == nil)
        #expect(viewModel.audioPlaybackState == .unavailable)
    }

    @Test("Playback toggles between playing and paused states")
    func playbackToggles() async {
        let audioURL = URL(filePath: "/tmp/audio/morning.m4a")
        let playbackService = AudioPlaybackServiceStub(duration: 12)
        let viewModel = MemoryDetailViewModel(
            memoryID: UUID(),
            repository: MemoryDetailRepositoryStub(memory: makeMemory()),
            mediaStore: ManagedMediaReaderStub(urls: ["audio/morning.m4a": audioURL]),
            audioPlaybackService: playbackService
        )

        await viewModel.load()
        viewModel.togglePlayback()
        #expect(viewModel.audioPlaybackState == .playing(elapsed: 0, duration: 12))

        viewModel.togglePlayback()
        #expect(viewModel.audioPlaybackState == .paused(elapsed: 0, duration: 12))
    }

    private func makeMemory() -> MemorySummary {
        MemorySummary(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            title: "Morning Rain",
            caption: "Rain on the porch.",
            capturedAt: .init(timeIntervalSince1970: 1),
            thumbnail: .managedFile("photos/morning.heic"),
            hasAudio: true,
            audioFilename: "audio/morning.m4a",
            audioDurationSeconds: 12,
            locationName: nil,
            journalNames: []
        )
    }
}

@MainActor
private final class MemoryDetailRepositoryStub: MemoryRepository {
    private let memory: MemorySummary?

    init(memory: MemorySummary?) {
        self.memory = memory
    }

    func fetchActiveMemories() async throws -> [MemorySummary] { memory.map { [$0] } ?? [] }
    func fetchActiveMemories(journalID: UUID) async throws -> [MemorySummary] { [] }
    func fetchActiveMemory(id: UUID) async throws -> MemorySummary? { memory }
    func createMemory(from draft: MemoryDraft, origin: MemoryCreationOrigin) throws -> Memory {
        throw MemoryDetailTestError.unavailable
    }
    func updateJournalAssignments(memoryID: UUID, journalIDs: Set<UUID>) throws {
        throw MemoryDetailTestError.unavailable
    }
    func moveToRecentlyDeleted(memoryID: UUID, at date: Date) throws {
        throw MemoryDetailTestError.unavailable
    }
}

@MainActor
private final class ManagedMediaReaderStub: ManagedMediaReading {
    private let urls: [String: URL]

    init(urls: [String: URL]) {
        self.urls = urls
    }

    func fileURL(for filename: String) throws -> URL {
        guard let url = urls[filename] else { throw MemoryDetailTestError.unavailable }
        return url
    }
}

@MainActor
private final class AudioPlaybackServiceStub: AudioPlaybackServicing {
    let duration: TimeInterval
    private(set) var currentTime: TimeInterval = 0
    private(set) var isPlaying = false
    private(set) var loadedURL: URL?

    init(duration: TimeInterval) {
        self.duration = duration
    }

    func loadAudio(at url: URL) async throws {
        loadedURL = url
        currentTime = 0
    }

    func play() throws {
        guard loadedURL != nil else { throw MemoryDetailTestError.unavailable }
        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func stop() async {
        currentTime = 0
        isPlaying = false
    }
}

private enum MemoryDetailTestError: Error {
    case unavailable
}
