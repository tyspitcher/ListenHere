// Renders the root All Memories list, loading states, deletion confirmation, and create-memory entry point.

import Foundation
import SwiftUI

struct AllMemoriesView: View {
    @State private var viewModel: AllMemoriesViewModel
    @State private var captureViewModel: CaptureViewModel?
    @State private var editSession: MemoryEditSessionViewModel?
    @State private var journalAssignmentViewModel: MemoryJournalAssignmentViewModel?

    let openLibrary: () -> Void
    let openMemory: (UUID) -> Void
    let makeCaptureViewModel: () -> CaptureViewModel
    let makeVoiceRecordingViewModel: (CaptureViewModel) -> CaptureRecordingSession
    let makeCaptureMediaPreviewViewModel: (CaptureViewModel) -> AudioPreviewViewModel
    let makeCameraCaptureViewModel: () -> CameraCaptureViewModel
    let makeMemoryEditSession: (MemorySummary) -> MemoryEditSessionViewModel
    let makeMemoryJournalAssignmentViewModel: (MemorySummary) -> MemoryJournalAssignmentViewModel
    let makeVoiceRecordingViewModelForEditing: (MemoryEditSessionViewModel) -> VoiceRecordingViewModel
    let makeAudioPreviewViewModelForEditing: (MemoryEditSessionViewModel) -> AudioPreviewViewModel
    let makeLocationPickerViewModel: LocationPickerViewModelFactory

    init(
        viewModel: AllMemoriesViewModel,
        openLibrary: @escaping () -> Void,
        openMemory: @escaping (UUID) -> Void,
        makeCaptureViewModel: @escaping () -> CaptureViewModel,
        makeVoiceRecordingViewModel: @escaping (CaptureViewModel) -> CaptureRecordingSession,
        makeCaptureMediaPreviewViewModel: @escaping (CaptureViewModel) -> AudioPreviewViewModel,
        makeCameraCaptureViewModel: @escaping () -> CameraCaptureViewModel,
        makeMemoryEditSession: @escaping (MemorySummary) -> MemoryEditSessionViewModel,
        makeMemoryJournalAssignmentViewModel: @escaping (MemorySummary) -> MemoryJournalAssignmentViewModel,
        makeVoiceRecordingViewModelForEditing: @escaping (MemoryEditSessionViewModel) -> VoiceRecordingViewModel,
        makeAudioPreviewViewModelForEditing: @escaping (MemoryEditSessionViewModel) -> AudioPreviewViewModel,
        makeLocationPickerViewModel: @escaping LocationPickerViewModelFactory
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.openLibrary = openLibrary
        self.openMemory = openMemory
        self.makeCaptureViewModel = makeCaptureViewModel
        self.makeVoiceRecordingViewModel = makeVoiceRecordingViewModel
        self.makeCaptureMediaPreviewViewModel = makeCaptureMediaPreviewViewModel
        self.makeCameraCaptureViewModel = makeCameraCaptureViewModel
        self.makeMemoryEditSession = makeMemoryEditSession
        self.makeMemoryJournalAssignmentViewModel = makeMemoryJournalAssignmentViewModel
        self.makeVoiceRecordingViewModelForEditing = makeVoiceRecordingViewModelForEditing
        self.makeAudioPreviewViewModelForEditing = makeAudioPreviewViewModelForEditing
        self.makeLocationPickerViewModel = makeLocationPickerViewModel
    }

    var body: some View {
        AllMemoriesContentView(
            viewModel: viewModel,
            openMemory: openMemory,
            presentCapture: presentCapture,
            requestDeletion: { viewModel.delete($0) },
            presentEdit: { editSession = makeMemoryEditSession($0) },
            presentJournalAssignment: { journalAssignmentViewModel = makeMemoryJournalAssignmentViewModel($0) }
        )
        .navigationTitle("All Memories")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: openLibrary) {
                    Label("Library", systemImage: "square.grid.2x2")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presentCapture()
                } label: {
                    Label("New Memory", systemImage: "plus")
                }
            }
        }
        .sheet(item: $captureViewModel) { viewModel in
            CaptureComposerSheet(
                viewModel: viewModel,
                makeVoiceRecordingViewModel: makeVoiceRecordingViewModel,
                makeCaptureMediaPreviewViewModel: makeCaptureMediaPreviewViewModel,
                makeCameraCaptureViewModel: makeCameraCaptureViewModel,
                makeLocationPickerViewModel: makeLocationPickerViewModel,
                onSaved: finishCapture
            )
            // The captured draft is the sheet item's identity. Reset child-owned recording and
            // playback state whenever a new draft is presented, so it cannot retain an older draft.
            .id(viewModel.id)
        }
        .sheet(item: $editSession) { session in
            MemoryEditorSheet(
                session: session,
                recordingViewModel: makeVoiceRecordingViewModelForEditing(session),
                audioPreviewViewModel: makeAudioPreviewViewModelForEditing(session),
                makeLocationPickerViewModel: makeLocationPickerViewModel
            ) {
                viewModel.load()
            }
        }
        .sheet(item: $journalAssignmentViewModel) { journalAssignmentViewModel in
            MemoryJournalAssignmentSheet(viewModel: journalAssignmentViewModel) {
                viewModel.load()
            }
        }
    }

    private func presentCapture() {
        captureViewModel = makeCaptureViewModel()
    }

    private func finishCapture() {
        captureViewModel = nil
        viewModel.load()
    }
}

#if DEBUG
#Preview("Populated") {
    NavigationStack {
        AllMemoriesView(
            viewModel: AllMemoriesViewModel(repository: PreviewMemoryRepository()),
            openLibrary: {},
            openMemory: { _ in },
            makeCaptureViewModel: makePreviewCaptureViewModel,
            makeVoiceRecordingViewModel: makePreviewVoiceRecordingViewModel,
            makeCaptureMediaPreviewViewModel: makePreviewCaptureMediaPreviewViewModel,
            makeCameraCaptureViewModel: makePreviewCameraCaptureViewModel,
            makeMemoryEditSession: makePreviewMemoryEditSession,
            makeMemoryJournalAssignmentViewModel: makePreviewMemoryJournalAssignmentViewModel,
            makeVoiceRecordingViewModelForEditing: makePreviewEditingVoiceRecordingViewModel,
            makeAudioPreviewViewModelForEditing: makePreviewEditingAudioPreviewViewModel,
            makeLocationPickerViewModel: makePreviewLocationPickerViewModel
        )
    }
    .appTheme(.listenHere)
}

#Preview("Empty") {
    NavigationStack {
        AllMemoriesView(
            viewModel: AllMemoriesViewModel(repository: PreviewMemoryRepository(memories: [])),
            openLibrary: {},
            openMemory: { _ in },
            makeCaptureViewModel: makePreviewCaptureViewModel,
            makeVoiceRecordingViewModel: makePreviewVoiceRecordingViewModel,
            makeCaptureMediaPreviewViewModel: makePreviewCaptureMediaPreviewViewModel,
            makeCameraCaptureViewModel: makePreviewCameraCaptureViewModel,
            makeMemoryEditSession: makePreviewMemoryEditSession,
            makeMemoryJournalAssignmentViewModel: makePreviewMemoryJournalAssignmentViewModel,
            makeVoiceRecordingViewModelForEditing: makePreviewEditingVoiceRecordingViewModel,
            makeAudioPreviewViewModelForEditing: makePreviewEditingAudioPreviewViewModel,
            makeLocationPickerViewModel: makePreviewLocationPickerViewModel
        )
    }
    .appTheme(.listenHere)
}

#Preview("Error") {
    NavigationStack {
        AllMemoriesView(
            viewModel: AllMemoriesViewModel(
                repository: PreviewMemoryRepository(
                    loadError: PreviewRepositoryError.requestedFailure
                )
            ),
            openLibrary: {},
            openMemory: { _ in },
            makeCaptureViewModel: makePreviewCaptureViewModel,
            makeVoiceRecordingViewModel: makePreviewVoiceRecordingViewModel,
            makeCaptureMediaPreviewViewModel: makePreviewCaptureMediaPreviewViewModel,
            makeCameraCaptureViewModel: makePreviewCameraCaptureViewModel,
            makeMemoryEditSession: makePreviewMemoryEditSession,
            makeMemoryJournalAssignmentViewModel: makePreviewMemoryJournalAssignmentViewModel,
            makeVoiceRecordingViewModelForEditing: makePreviewEditingVoiceRecordingViewModel,
            makeAudioPreviewViewModelForEditing: makePreviewEditingAudioPreviewViewModel,
            makeLocationPickerViewModel: makePreviewLocationPickerViewModel
        )
    }
    .appTheme(.listenHere)
}

#Preview("Dark, Large Type") {
    NavigationStack {
        AllMemoriesView(
            viewModel: AllMemoriesViewModel(repository: PreviewMemoryRepository()),
            openLibrary: {},
            openMemory: { _ in },
            makeCaptureViewModel: makePreviewCaptureViewModel,
            makeVoiceRecordingViewModel: makePreviewVoiceRecordingViewModel,
            makeCaptureMediaPreviewViewModel: makePreviewCaptureMediaPreviewViewModel,
            makeCameraCaptureViewModel: makePreviewCameraCaptureViewModel,
            makeMemoryEditSession: makePreviewMemoryEditSession,
            makeMemoryJournalAssignmentViewModel: makePreviewMemoryJournalAssignmentViewModel,
            makeVoiceRecordingViewModelForEditing: makePreviewEditingVoiceRecordingViewModel,
            makeAudioPreviewViewModelForEditing: makePreviewEditingAudioPreviewViewModel,
            makeLocationPickerViewModel: makePreviewLocationPickerViewModel
        )
    }
    .appTheme(.listenHere)
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("iPad") {
    NavigationStack {
        AllMemoriesView(
            viewModel: AllMemoriesViewModel(repository: PreviewMemoryRepository()),
            openLibrary: {},
            openMemory: { _ in },
            makeCaptureViewModel: makePreviewCaptureViewModel,
            makeVoiceRecordingViewModel: makePreviewVoiceRecordingViewModel,
            makeCaptureMediaPreviewViewModel: makePreviewCaptureMediaPreviewViewModel,
            makeCameraCaptureViewModel: makePreviewCameraCaptureViewModel,
            makeMemoryEditSession: makePreviewMemoryEditSession,
            makeMemoryJournalAssignmentViewModel: makePreviewMemoryJournalAssignmentViewModel,
            makeVoiceRecordingViewModelForEditing: makePreviewEditingVoiceRecordingViewModel,
            makeAudioPreviewViewModelForEditing: makePreviewEditingAudioPreviewViewModel,
            makeLocationPickerViewModel: makePreviewLocationPickerViewModel
        )
    }
    .appTheme(.listenHere)
    .frame(width: 834, height: 1_194)
}

@MainActor
private func makePreviewCaptureViewModel() -> CaptureViewModel {
    CaptureViewModel(
        origin: .allMemories,
        memoryRepository: PreviewMemoryRepository(),
        mediaStore: PreviewManagedMediaStore()
    )
}

@MainActor
private func makePreviewVoiceRecordingViewModel(
    captureViewModel: CaptureViewModel
) -> CaptureRecordingSession {
    let viewModel = VoiceRecordingViewModel(
        service: PreviewAudioRecordingService(),
        clock: ContinuousRecordingClock()
    ) { recording in
        captureViewModel.importAudio(
            recording.data,
            preferredFileExtension: "m4a",
            durationSeconds: recording.duration
        )
    }
    return CaptureRecordingSession(viewModel: viewModel, photoCameraController: nil)
}

@MainActor
private func makePreviewCaptureMediaPreviewViewModel(
    captureViewModel: CaptureViewModel
) -> AudioPreviewViewModel {
    AudioPreviewViewModel(
        audioURL: { captureViewModel.managedAudioURL },
        fallbackDuration: { captureViewModel.draft.audioDurationSeconds },
        audioPlaybackService: PreviewAudioPlaybackService(),
        waveformAnalyzer: PreviewAudioWaveformAnalyzer()
    )
}

@MainActor
private func makePreviewCameraCaptureViewModel() -> CameraCaptureViewModel {
    CameraCaptureViewModel(authorizationService: PreviewCameraAuthorizationService())
}

@MainActor
private func makePreviewMemoryEditSession(memory: MemorySummary) -> MemoryEditSessionViewModel {
    MemoryEditSessionViewModel(
        memory: memory,
        repository: PreviewMemoryRepository(),
        journalRepository: ConfigurablePreviewJournalRepository(journals: []),
        mediaStore: PreviewManagedMediaStore()
    )
}

@MainActor
private func makePreviewMemoryJournalAssignmentViewModel(
    memory: MemorySummary
) -> MemoryJournalAssignmentViewModel {
    MemoryJournalAssignmentViewModel(
        memory: memory,
        memoryRepository: PreviewMemoryRepository(),
        journalRepository: ConfigurablePreviewJournalRepository(journals: [])
    )
}

@MainActor
private func makePreviewEditingVoiceRecordingViewModel(
    editSession: MemoryEditSessionViewModel
) -> VoiceRecordingViewModel {
    VoiceRecordingViewModel(
        service: PreviewAudioRecordingService(),
        clock: ContinuousRecordingClock()
    ) { recording in
        editSession.replaceAudio(
            recording.data,
            fileExtension: "m4a",
            duration: recording.duration
        )
    }
}

@MainActor
private func makePreviewEditingAudioPreviewViewModel(
    editSession: MemoryEditSessionViewModel
) -> AudioPreviewViewModel {
    AudioPreviewViewModel(
        audioURL: { editSession.audioURL },
        fallbackDuration: { editSession.audioDurationSeconds },
        audioPlaybackService: PreviewAudioPlaybackService(),
        waveformAnalyzer: PreviewAudioWaveformAnalyzer()
    )
}
#endif
