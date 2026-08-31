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
        allMemoriesViewModel = AllMemoriesViewModel(
            repository: memoryRepository,
            mediaReader: mediaStore
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
            mediaStore: mediaStore
        )
    }

    func makeJournalsViewModel() -> JournalsViewModel {
        JournalsViewModel(repository: journalRepository)
    }

    func makeJournalDetailViewModel(journalID: UUID) -> JournalDetailViewModel {
        JournalDetailViewModel(
            journalID: journalID,
            repository: memoryRepository,
            mediaReader: mediaStore
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
            audioPlaybackService: audioPlaybackServiceFactory()
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
}
