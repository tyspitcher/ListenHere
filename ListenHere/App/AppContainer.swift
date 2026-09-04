// Composes ListenHere's shared repositories, media storage, and navigation dependencies.
// It also creates feature view models with the live dependency graph.

import Foundation
import Observation

@MainActor
@Observable
final class AppContainer {
    let router: AppRouter
    let allMemoriesViewModel: AllMemoriesViewModel

    private let memoryRepository: any MemoryRepository
    private let journalRepository: any JournalRepository
    private let recentlyDeletedRepository: any RecentlyDeletedRepository
    private let mediaStore: any ManagedMediaStoring & ManagedMediaDeleting & ManagedMediaReading
    private let audioRecordingServiceFactory: @MainActor () -> any AudioRecordingServicing
    private let audioPlaybackServiceFactory: @MainActor () -> any AudioPlaybackServicing
    private let cameraAuthorizationServiceFactory: @MainActor () -> any CameraAuthorizationServicing
    private let waveformAnalyzerFactory: @MainActor () -> any AudioWaveformAnalyzing
    private let currentLocationProviderFactory: @MainActor () -> any CurrentLocationProviding
    private let locationNameResolverFactory: @MainActor () -> any LocationNameResolving

    init(
        memoryRepository: any MemoryRepository,
        journalRepository: any JournalRepository,
        recentlyDeletedRepository: any RecentlyDeletedRepository,
        mediaStore: any ManagedMediaStoring & ManagedMediaDeleting & ManagedMediaReading,
        navigationStateStore: (any NavigationStateStore)? = nil,
        audioRecordingServiceFactory: @escaping @MainActor () -> any AudioRecordingServicing = {
            AVFoundationAudioRecordingService()
        },
        audioPlaybackServiceFactory: @escaping @MainActor () -> any AudioPlaybackServicing = {
            AVFoundationAudioPlaybackService()
        },
        cameraAuthorizationServiceFactory: @escaping @MainActor () -> any CameraAuthorizationServicing = {
            AVFoundationCameraAuthorizationService()
        },
        waveformAnalyzerFactory: @escaping @MainActor () -> any AudioWaveformAnalyzing = {
            AVFoundationAudioWaveformAnalyzer()
        },
        currentLocationProviderFactory: @escaping @MainActor () -> any CurrentLocationProviding = {
            CoreLocationCurrentLocationProvider()
        },
        locationNameResolverFactory: @escaping @MainActor () -> any LocationNameResolving = {
            MapKitLocationNameResolver()
        }
    ) {
        self.memoryRepository = memoryRepository
        self.journalRepository = journalRepository
        self.recentlyDeletedRepository = recentlyDeletedRepository
        self.mediaStore = mediaStore
        self.audioRecordingServiceFactory = audioRecordingServiceFactory
        self.audioPlaybackServiceFactory = audioPlaybackServiceFactory
        self.cameraAuthorizationServiceFactory = cameraAuthorizationServiceFactory
        self.waveformAnalyzerFactory = waveformAnalyzerFactory
        self.currentLocationProviderFactory = currentLocationProviderFactory
        self.locationNameResolverFactory = locationNameResolverFactory
        allMemoriesViewModel = AllMemoriesViewModel(
            repository: memoryRepository,
            mediaReader: mediaStore,
            locationNameBackfiller: MemoryLocationNameBackfillService(
                repository: memoryRepository,
                locationNameResolver: locationNameResolverFactory()
            )
        )
        router = AppRouter(
            stateStore: navigationStateStore ?? UserDefaultsNavigationStateStore(),
            memoryRepository: memoryRepository,
            journalRepository: journalRepository
        )
    }

    func makeCaptureViewModel(origin: MemoryCreationOrigin) -> CaptureViewModel {
        CaptureViewModel(
            origin: origin,
            memoryRepository: memoryRepository,
            mediaStore: mediaStore,
            photoLocationExtractor: ImageIOPhotoLocationExtractor(),
            currentLocationProvider: currentLocationProviderFactory(),
            locationNameResolver: locationNameResolverFactory()
        )
    }

    func makeJournalsViewModel() -> JournalsViewModel {
        JournalsViewModel(repository: journalRepository)
    }

    func makePlacesViewModel() -> PlacesViewModel {
        PlacesViewModel(
            repository: memoryRepository,
            mediaReader: mediaStore,
            locationNameBackfiller: makeLocationNameBackfiller()
        )
    }

    func makeLocationPickerViewModel(
        candidates: [MemoryLocationCandidate],
        initialLocation: MemoryLocation?
    ) -> LocationPickerViewModel {
        LocationPickerViewModel(
            candidates: candidates,
            initialLocation: initialLocation,
            currentLocationProvider: currentLocationProviderFactory(),
            locationNameResolver: locationNameResolverFactory()
        )
    }

    func makeJournalDetailViewModel(journalID: UUID) -> JournalDetailViewModel {
        JournalDetailViewModel(
            journalID: journalID,
            repository: memoryRepository,
            journalRepository: journalRepository,
            mediaReader: mediaStore,
            locationNameBackfiller: makeLocationNameBackfiller()
        )
    }

    func makeRecentlyDeletedViewModel() -> RecentlyDeletedViewModel {
        RecentlyDeletedViewModel(repository: recentlyDeletedRepository)
    }

    func makeMemoryDetailViewModel(memoryID: UUID) -> MemoryDetailViewModel {
        MemoryDetailViewModel(
            memoryID: memoryID,
            repository: memoryRepository,
            journalRepository: journalRepository,
            mediaStore: mediaStore,
            mediaEditor: mediaStore,
            audioPlaybackService: audioPlaybackServiceFactory(),
            locationNameBackfiller: makeLocationNameBackfiller()
        )
    }

    func makeMemoryEditSession(memory: MemorySummary) -> MemoryEditSessionViewModel {
        MemoryEditSessionViewModel(
            memory: memory,
            repository: memoryRepository,
            journalRepository: journalRepository,
            mediaStore: mediaStore
        )
    }

    func makeMemoryJournalAssignmentViewModel(
        memory: MemorySummary
    ) -> MemoryJournalAssignmentViewModel {
        MemoryJournalAssignmentViewModel(
            memory: memory,
            memoryRepository: memoryRepository,
            journalRepository: journalRepository
        )
    }

    func makeVoiceRecordingViewModel(
        editSession: MemoryEditSessionViewModel
    ) -> VoiceRecordingViewModel {
        VoiceRecordingViewModel(
            service: audioRecordingServiceFactory(),
            clock: ContinuousRecordingClock()
        ) { recording in
            editSession.replaceAudio(
                recording.data,
                fileExtension: "m4a",
                duration: recording.duration
            )
        }
    }

    func makeVoiceRecordingViewModel(captureViewModel: CaptureViewModel) -> VoiceRecordingViewModel {
        VoiceRecordingViewModel(
            service: audioRecordingServiceFactory(),
            clock: ContinuousRecordingClock()
        ) { recording in
            captureViewModel.importAudio(
                recording.data,
                preferredFileExtension: "m4a",
                durationSeconds: recording.duration
            )
        }
    }

    func makeCaptureMediaPreviewViewModel(
        captureViewModel: CaptureViewModel
    ) -> CaptureMediaPreviewViewModel {
        CaptureMediaPreviewViewModel(
            captureViewModel: captureViewModel,
            audioPlaybackService: audioPlaybackServiceFactory(),
            waveformAnalyzer: waveformAnalyzerFactory()
        )
    }

    func makeCameraCaptureViewModel() -> CameraCaptureViewModel {
        CameraCaptureViewModel(authorizationService: cameraAuthorizationServiceFactory())
    }

    private func makeLocationNameBackfiller() -> MemoryLocationNameBackfillService {
        MemoryLocationNameBackfillService(
            repository: memoryRepository,
            locationNameResolver: locationNameResolverFactory()
        )
    }
}
