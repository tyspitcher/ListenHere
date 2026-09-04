// Displays memories belonging to the selected journal-detail route.
import SwiftUI

struct MemoryListView: View {
    @State private var viewModel: JournalDetailViewModel
    @State private var captureViewModel: CaptureViewModel?
    @State private var memoryPendingDeletion: MemorySummary?
    @State private var editSession: MemoryEditSessionViewModel?
    @State private var journalAssignmentViewModel: MemoryJournalAssignmentViewModel?

    private let openMemory: (UUID) -> Void
    private let makeCaptureViewModel: () -> CaptureViewModel
    private let makeVoiceRecordingViewModel: (CaptureViewModel) -> VoiceRecordingViewModel
    private let makeCaptureMediaPreviewViewModel: (CaptureViewModel) -> CaptureMediaPreviewViewModel
    private let makeCameraCaptureViewModel: () -> CameraCaptureViewModel
    private let makeMemoryEditSession: (MemorySummary) -> MemoryEditSessionViewModel
    private let makeMemoryJournalAssignmentViewModel: (MemorySummary) -> MemoryJournalAssignmentViewModel
    private let makeVoiceRecordingViewModelForEditing: (MemoryEditSessionViewModel) -> VoiceRecordingViewModel
    private let makeLocationPickerViewModel: LocationPickerViewModelFactory

    init(
        viewModel: JournalDetailViewModel,
        openMemory: @escaping (UUID) -> Void,
        makeCaptureViewModel: @escaping () -> CaptureViewModel,
        makeVoiceRecordingViewModel: @escaping (CaptureViewModel) -> VoiceRecordingViewModel,
        makeCaptureMediaPreviewViewModel: @escaping (CaptureViewModel) -> CaptureMediaPreviewViewModel,
        makeCameraCaptureViewModel: @escaping () -> CameraCaptureViewModel,
        makeMemoryEditSession: @escaping (MemorySummary) -> MemoryEditSessionViewModel,
        makeMemoryJournalAssignmentViewModel: @escaping (MemorySummary) -> MemoryJournalAssignmentViewModel,
        makeVoiceRecordingViewModelForEditing: @escaping (MemoryEditSessionViewModel) -> VoiceRecordingViewModel,
        makeLocationPickerViewModel: @escaping LocationPickerViewModelFactory
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.openMemory = openMemory
        self.makeCaptureViewModel = makeCaptureViewModel
        self.makeVoiceRecordingViewModel = makeVoiceRecordingViewModel
        self.makeCaptureMediaPreviewViewModel = makeCaptureMediaPreviewViewModel
        self.makeCameraCaptureViewModel = makeCameraCaptureViewModel
        self.makeMemoryEditSession = makeMemoryEditSession
        self.makeMemoryJournalAssignmentViewModel = makeMemoryJournalAssignmentViewModel
        self.makeVoiceRecordingViewModelForEditing = makeVoiceRecordingViewModelForEditing
        self.makeLocationPickerViewModel = makeLocationPickerViewModel
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .unavailable:
                ContentUnavailableView("Journal Unavailable", systemImage: "book.closed")
            case .loaded(let memories) where memories.isEmpty:
                ContentUnavailableView(
                    "No Memories",
                    systemImage: "photo.on.rectangle",
                    description: Text("Memories assigned to this journal will appear here.")
                )
            case .loaded(let memories):
                ScrollView {
                    LazyVStack(spacing: 22) {
                        ForEach(memories) { memory in
                            MemoryCardRowView(
                                memory: memory,
                                managedPhotoURL: viewModel.managedPhotoURL(for: memory),
                                open: { openMemory(memory.id) },
                                edit: { editSession = makeMemoryEditSession(memory) },
                                chooseJournals: {
                                    journalAssignmentViewModel = makeMemoryJournalAssignmentViewModel(memory)
                                },
                                delete: { memoryPendingDeletion = memory }
                            )
                        }
                    }
                    .padding()
                }
            case .loading:
                ProgressView("Loading Journal")
            }
        }
        .navigationTitle(viewModel.journalTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Memory", systemImage: "plus", action: presentCapture)
            }
        }
        .sheet(item: $captureViewModel) { captureViewModel in
            CaptureComposerSheet(
                viewModel: captureViewModel,
                makeVoiceRecordingViewModel: makeVoiceRecordingViewModel,
                makeCaptureMediaPreviewViewModel: makeCaptureMediaPreviewViewModel,
                makeCameraCaptureViewModel: makeCameraCaptureViewModel,
                makeLocationPickerViewModel: makeLocationPickerViewModel,
                onSaved: finishCapture
            )
            .id(captureViewModel.id)
        }
        .sheet(item: $editSession) { session in
            MemoryEditorSheet(
                session: session,
                recordingViewModel: makeVoiceRecordingViewModelForEditing(session),
                makeLocationPickerViewModel: makeLocationPickerViewModel
            ) {
                await viewModel.load()
            }
        }
        .sheet(item: $journalAssignmentViewModel) { journalAssignmentViewModel in
            MemoryJournalAssignmentSheet(viewModel: journalAssignmentViewModel) {
                Task { await viewModel.load() }
            }
        }
        .confirmationDialog(
            "Delete Memory?",
            isPresented: deletionIsPresented,
            presenting: memoryPendingDeletion
        ) { memory in
            Button("Move to Recently Deleted", role: .destructive) {
                viewModel.delete(memory)
                memoryPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                memoryPendingDeletion = nil
            }
        } message: { _ in
            Text("You can recover this memory for 30 days.")
        }
        .alert("Couldn’t Delete Memory", isPresented: deletionErrorIsPresented) {
            Button("OK", action: viewModel.dismissDeletionError)
        } message: {
            Text(viewModel.deletionErrorMessage ?? "Please try again.")
        }
        .task { await viewModel.load() }
        .appScreenBackground()
    }

    private func presentCapture() {
        captureViewModel = makeCaptureViewModel()
    }

    private func finishCapture() {
        captureViewModel = nil
        Task { await viewModel.load() }
    }

    private var deletionIsPresented: Binding<Bool> {
        Binding(
            get: { memoryPendingDeletion != nil },
            set: { if $0 == false { memoryPendingDeletion = nil } }
        )
    }

    private var deletionErrorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.deletionErrorMessage != nil },
            set: { if $0 == false { viewModel.dismissDeletionError() } }
        )
    }
}
