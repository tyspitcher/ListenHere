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

    @Test("Recently deleted memories load without allowing an edit session")
    func recentlyDeletedMemoryIsReadOnly() async {
        let memory = makeMemory()
        let mediaStore = InMemoryManagedMediaStore()
        let viewModel = MemoryDetailViewModel(
            memoryID: memory.id,
            access: .recentlyDeleted,
            repository: MemoryDetailRepositoryStub(
                memory: nil,
                recentlyDeletedMemory: memory
            ),
            mediaStore: mediaStore,
            mediaEditor: mediaStore,
            audioPlaybackService: AudioPlaybackServiceStub(duration: 12)
        )

        await viewModel.load()

        #expect(viewModel.state == .loaded(memory))
        #expect(viewModel.canEdit == false)
        #expect(viewModel.makeEditSession(for: memory) == nil)
        #expect(viewModel.canShare == false)
        #expect(viewModel.sharingAvailability(for: memory) == nil)
    }

    @Test("Photo-and-sound memories offer each share representation")
    func photoAndSoundMemoryOffersEachSharingRepresentation() {
        let memory = makeMemory()
        let viewModel = makeViewModel()

        #expect(viewModel.sharingAvailability(for: memory) == .photoAndAudio)
    }

    @Test("Sharing keeps photo-only and audio-only memories in their original formats")
    func sharingSelectsTheCorrectMediaPath() {
        let viewModel = makeViewModel()

        #expect(viewModel.sharingAvailability(for: makeMemory(thumbnail: nil, hasAudio: true)) == .audio)
        #expect(viewModel.sharingAvailability(for: makeMemory(thumbnail: .managedFile("photos/morning.heic"), hasAudio: false)) == .photo)
        #expect(viewModel.sharingAvailability(for: makeMemory(thumbnail: nil, hasAudio: false)) == .unavailable)
    }

    @Test("Recently deleted detail recovers its memory through the recovery capability")
    func recentlyDeletedMemoryRecovers() {
        let memory = makeMemory()
        let recoveryService = RecoveryServiceStub()
        let viewModel = MemoryDetailViewModel(
            memoryID: memory.id,
            access: .recentlyDeleted,
            repository: MemoryDetailRepositoryStub(memory: nil),
            mediaStore: ManagedMediaReaderStub(urls: [:]),
            recoveryService: recoveryService,
            audioPlaybackService: AudioPlaybackServiceStub(duration: 12)
        )

        let didRecover = viewModel.recover(at: Date(timeIntervalSince1970: 1_000))

        #expect(didRecover)
        #expect(recoveryService.recoveredIDs == [.init(kind: .memory, modelID: memory.id)])
    }

    @Test("Pausing preserves the current elapsed time")
    func pausingPreservesElapsedTime() async {
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
        playbackService.setCurrentTime(4.5)

        viewModel.togglePlayback()

        #expect(viewModel.audioPlaybackState == .paused(elapsed: 4.5, duration: 12))
    }

    private func makeViewModel() -> MemoryDetailViewModel {
        MemoryDetailViewModel(
            memoryID: UUID(),
            repository: MemoryDetailRepositoryStub(memory: makeMemory()),
            mediaStore: ManagedMediaReaderStub(urls: [:]),
            audioPlaybackService: AudioPlaybackServiceStub(duration: 12)
        )
    }

    private func makeMemory(
        thumbnail: MemorySummary.Thumbnail? = .managedFile("photos/morning.heic"),
        hasAudio: Bool = true
    ) -> MemorySummary {
        MemorySummary(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            title: "Morning Rain",
            caption: "Rain on the porch.",
            capturedAt: .init(timeIntervalSince1970: 1),
            thumbnail: thumbnail,
            hasAudio: hasAudio,
            audioFilename: hasAudio ? "audio/morning.m4a" : nil,
            audioDurationSeconds: 12,
            locationName: nil,
            journalNames: []
        )
    }
}

@MainActor
private final class MemoryDetailRepositoryStub: MemoryRepository {
    private let memory: MemorySummary?
    private let recentlyDeletedMemory: MemorySummary?

    init(memory: MemorySummary?, recentlyDeletedMemory: MemorySummary? = nil) {
        self.memory = memory
        self.recentlyDeletedMemory = recentlyDeletedMemory
    }

    func fetchActiveMemories() async throws -> [MemorySummary] { memory.map { [$0] } ?? [] }
    func fetchActiveMemories(journalID: UUID) async throws -> [MemorySummary] { [] }
    func fetchActiveMemory(id: UUID) async throws -> MemorySummary? { memory }
    func fetchRecentlyDeletedMemory(id: UUID) async throws -> MemorySummary? {
        recentlyDeletedMemory
    }
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
private final class RecoveryServiceStub: RecentlyDeletedRecovering {
    private(set) var recoveredIDs: [RecentlyDeletedItem.ID] = []

    func recover(_ itemID: RecentlyDeletedItem.ID, at date: Date) throws {
        recoveredIDs.append(itemID)
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

    func setCurrentTime(_ time: TimeInterval) {
        currentTime = time
    }
}

private enum MemoryDetailTestError: Error {
    case unavailable
}
