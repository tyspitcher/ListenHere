// Supplies deterministic preview memories, in-memory repositories, SwiftData fixtures, and no-I/O media doubles.
#if DEBUG
import Foundation
import SwiftData

enum PreviewFixtures {
    static let forestID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1))
    static let beachID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2))
    static let soundOnlyID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 3))

    static let memories: [MemorySummary] = [
        MemorySummary(
            id: forestID,
            title: "Wind Through the Pines",
            caption: "Morning light moved through the trees while the forest woke up.",
            capturedAt: Date(timeIntervalSince1970: 1_695_945_600),
            thumbnail: .previewAsset("ForestMemory"),
            hasAudio: true,
            audioFilename: "preview/forest.m4a",
            audioDurationSeconds: 22,
            locationName: "Mount Rainier, WA",
            location: MemoryLocation(
                latitude: 46.85,
                longitude: -121.76,
                name: "Mount Rainier, WA"
            ),
            journalNames: ["Nature Sounds", "Everyday"]
        ),
        MemorySummary(
            id: beachID,
            title: "Harbor at Low Tide",
            caption: "The boats were all in and the gulls were quiet—just the water pulling back.",
            capturedAt: Date(timeIntervalSince1970: 1_689_724_800),
            thumbnail: .previewAsset("BeachMemory"),
            hasAudio: false,
            audioFilename: nil,
            audioDurationSeconds: nil,
            locationName: "Portland, ME",
            location: MemoryLocation(
                latitude: 43.66,
                longitude: -70.25,
                name: "Portland, ME"
            ),
            journalNames: ["Daily Fragments"]
        ),
        MemorySummary(
            id: soundOnlyID,
            title: "Rain on the Porch",
            caption: "A slow summer storm after everyone had gone to bed.",
            capturedAt: Date(timeIntervalSince1970: 1_686_441_600),
            thumbnail: nil,
            hasAudio: true,
            audioFilename: "preview/rain.m4a",
            audioDurationSeconds: 30,
            locationName: nil,
            journalNames: ["Everyday"]
        ),
    ]

    @MainActor
    static func modelContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: ListenHereSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: ListenHereMigrationPlan.self,
            configurations: [configuration]
        )
        let context = container.mainContext

        let nature = Journal(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1)),
            name: "Nature Sounds",
            createdAt: Date(timeIntervalSince1970: 1_600_000_000),
            isDefault: true
        )
        let daily = Journal(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2)),
            name: "Daily Fragments",
            createdAt: Date(timeIntervalSince1970: 1_600_000_100)
        )
        context.insert(nature)
        context.insert(daily)

        let forest = Memory(
            id: forestID,
            capturedAt: memories[0].capturedAt,
            title: memories[0].title,
            caption: memories[0].caption,
            photoFilename: "ForestMemory",
            audioFilename: "preview/forest.m4a",
            audioDurationSeconds: 22
        )
        forest.setLocation(latitude: 46.85, longitude: -121.76, name: "Mount Rainier, WA")
        context.insert(forest)
        nature.add(forest)

        let beach = Memory(
            id: beachID,
            capturedAt: memories[1].capturedAt,
            title: memories[1].title,
            caption: memories[1].caption,
            photoFilename: "BeachMemory",
            audioFilename: "preview/beach.m4a",
            audioDurationSeconds: 18
        )
        beach.setLocation(latitude: 43.66, longitude: -70.25, name: "Portland, ME")
        context.insert(beach)
        daily.add(beach)

        try context.save()
        return container
    }
}

@MainActor
final class PreviewMemoryRepository: MemoryRepository {
    private var memories: [MemorySummary]
    var loadError: Error?

    init(memories: [MemorySummary]? = nil, loadError: Error? = nil) {
        self.memories = memories ?? PreviewFixtures.memories
        self.loadError = loadError
    }

    func fetchActiveMemories() async throws -> [MemorySummary] {
        if let loadError { throw loadError }
        return memories.sorted { $0.capturedAt > $1.capturedAt }
    }

    func fetchActiveMemory(id: UUID) async throws -> MemorySummary? {
        if let loadError { throw loadError }
        return memories.first { $0.id == id }
    }

    func fetchActiveMemories(journalID: UUID) async throws -> [MemorySummary] {
        if let loadError { throw loadError }
        return memories
    }

    func createMemory(from draft: MemoryDraft, origin: MemoryCreationOrigin) throws -> Memory {
        throw PreviewRepositoryError.readOnly
    }

    func updateJournalAssignments(memoryID: UUID, journalIDs: Set<UUID>) throws {
        throw PreviewRepositoryError.readOnly
    }

    func moveToRecentlyDeleted(memoryID: UUID, at date: Date) throws {
        memories.removeAll { $0.id == memoryID }
    }
}

@MainActor
final class ConfigurablePreviewJournalRepository: JournalRepository {
    private var journals: [JournalSummary]

    init(journals: [JournalSummary]) {
        self.journals = journals
    }

    func fetchActiveJournals() async throws -> [JournalSummary] {
        journals
    }

    func createJournal(name: String, at date: Date) throws -> Journal {
        throw PreviewRepositoryError.readOnly
    }

    func renameJournal(id: UUID, name: String, at date: Date) throws {
        throw PreviewRepositoryError.readOnly
    }

    func setDefaultJournal(id: UUID, at date: Date) throws {
        throw PreviewRepositoryError.readOnly
    }

    func moveToRecentlyDeleted(
        journalID: UUID,
        strategy: JournalDeletionStrategy,
        at date: Date
    ) throws {
        journals.removeAll { $0.id == journalID }
    }
}

enum PreviewRepositoryError: Error {
    case readOnly
    case requestedFailure
}

/// A preview-only media boundary keeps previews from creating app-managed files.
@MainActor
final class PreviewManagedMediaStore: ManagedMediaDeleting, ManagedMediaReading, ManagedMediaStoring {
    func store(
        _ data: Data,
        as kind: ManagedMediaKind,
        preferredFileExtension: String
    ) throws -> ManagedMediaFile {
        throw PreviewRepositoryError.readOnly
    }

    func deleteManagedFiles(named filenames: Set<String>) throws {}

    func fileURL(for filename: String) throws -> URL {
        throw PreviewRepositoryError.readOnly
    }
}

@MainActor
final class PreviewAudioRecordingService: AudioRecordingServicing {
    let events = AsyncStream<AudioRecordingServiceEvent> { $0.finish() }

    func requestPermission() async -> Bool { false }

    func start() async throws {
        throw PreviewRepositoryError.readOnly
    }

    func stop() async throws -> AudioRecording {
        throw PreviewRepositoryError.readOnly
    }

    func cancel() async {}
    func normalizedMeterLevel() -> Double { 0 }
}

@MainActor
final class PreviewCameraAuthorizationService: CameraAuthorizationServicing {
    func authorizationStatus() -> CameraAuthorizationStatus { .unavailable }
    func requestAccess() async -> Bool { false }
}

@MainActor
final class PreviewCurrentLocationProvider: CurrentLocationProviding {
    func requestCurrentLocation() async throws -> MemoryLocationCandidate {
        throw CurrentLocationError.unavailable
    }
}

@MainActor
final class PreviewLocationNameResolver: LocationNameResolving {
    func name(for location: MemoryLocation) async throws -> String? {
        location.normalizedName ?? "West Jordan, UT"
    }
}

@MainActor
func makePreviewLocationPickerViewModel(
    candidates: [MemoryLocationCandidate],
    initialLocation: MemoryLocation?
) -> LocationPickerViewModel {
    LocationPickerViewModel(
        candidates: candidates,
        initialLocation: initialLocation,
        currentLocationProvider: PreviewCurrentLocationProvider(),
        locationNameResolver: PreviewLocationNameResolver()
    )
}

struct PreviewAudioWaveformAnalyzer: AudioWaveformAnalyzing {
    nonisolated func samples(for url: URL, targetCount: Int) async throws -> [Double] {
        Array(repeating: 0.35, count: targetCount)
    }
}

@MainActor
final class PreviewAudioPlaybackService: AudioPlaybackServicing {
    var currentTime: TimeInterval { 0 }
    var duration: TimeInterval { 0 }
    var isPlaying: Bool { false }

    func loadAudio(at url: URL) async throws {
        throw PreviewRepositoryError.readOnly
    }

    func play() throws {
        throw PreviewRepositoryError.readOnly
    }

    func pause() {}
    func stop() async {}
}
#endif
