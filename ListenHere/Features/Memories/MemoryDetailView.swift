// Displays the selected memory's current metadata and media summary in a native detail layout.
import SwiftUI

struct MemoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: MemoryDetailViewModel
    @State private var editSession: MemoryEditSessionViewModel?
    @State private var sharingViewModel: MemoryShareViewModel?
    private let makeVoiceRecordingViewModel: (MemoryEditSessionViewModel) -> VoiceRecordingViewModel
    private let makeAudioPreviewViewModel: (MemoryEditSessionViewModel) -> AudioPreviewViewModel
    private let makeLocationPickerViewModel: LocationPickerViewModelFactory

    init(
        viewModel: MemoryDetailViewModel,
        makeVoiceRecordingViewModel: @escaping (MemoryEditSessionViewModel) -> VoiceRecordingViewModel,
        makeAudioPreviewViewModel: @escaping (MemoryEditSessionViewModel) -> AudioPreviewViewModel,
        makeLocationPickerViewModel: @escaping LocationPickerViewModelFactory
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.makeVoiceRecordingViewModel = makeVoiceRecordingViewModel
        self.makeAudioPreviewViewModel = makeAudioPreviewViewModel
        self.makeLocationPickerViewModel = makeLocationPickerViewModel
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loaded(let memory):
                MemoryDetailContentView(
                    memory: memory,
                    photoURL: viewModel.photoURL,
                    audioPlaybackState: viewModel.audioPlaybackState,
                    waveformSamples: viewModel.waveformSamples,
                    isRecentlyDeleted: viewModel.isRecentlyDeleted,
                    recoverMemory: recoverMemory,
                    togglePlayback: viewModel.togglePlayback,
                    seek: viewModel.seek
                )
            case .unavailable:
                ContentUnavailableView(
                    "Memory Unavailable",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text("This memory may have been deleted or moved.")
                )
            case .loading:
                ProgressView("Loading Memory")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .loaded(let memory) = viewModel.state {
                ToolbarItemGroup(placement: .primaryAction) {
                    if viewModel.canShare {
                        Button("Share Memory", systemImage: "square.and.arrow.up") {
                            sharingViewModel = viewModel.makeShareViewModel(for: memory)
                        }
                    }

                    if viewModel.canEdit {
                        Button("Edit", systemImage: "pencil") {
                            editSession = viewModel.makeEditSession(for: memory)
                        }
                    }
                }
            }
        }
        .sheet(item: $editSession) { session in
            MemoryEditorSheet(
                session: session,
                recordingViewModel: makeVoiceRecordingViewModel(session),
                audioPreviewViewModel: makeAudioPreviewViewModel(session),
                makeLocationPickerViewModel: makeLocationPickerViewModel
            ) {
                await viewModel.load()
            }
        }
        .sheet(item: $sharingViewModel) { sharingViewModel in
            ShareMemorySheet(viewModel: sharingViewModel)
        }
        .alert("Couldn’t Recover Memory", isPresented: recoveryErrorIsPresented) {
            Button("OK", action: viewModel.dismissRecoveryError)
        } message: {
            Text(viewModel.recoveryErrorMessage ?? "Please try again.")
        }
        .task { await viewModel.load() }
        .onDisappear {
            Task { await viewModel.stopPlayback() }
        }
        .appScreenBackground()
    }

    private var recoveryErrorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.recoveryErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    viewModel.dismissRecoveryError()
                }
            }
        )
    }

    private func recoverMemory() {
        if viewModel.recover() {
            dismiss()
        }
    }
}
