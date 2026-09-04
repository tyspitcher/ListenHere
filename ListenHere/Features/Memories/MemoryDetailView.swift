// Displays the selected memory's current metadata and media summary in a native detail layout.
import SwiftUI

struct MemoryDetailView: View {
    @State private var viewModel: MemoryDetailViewModel
    @State private var editSession: MemoryEditSessionViewModel?
    private let makeVoiceRecordingViewModel: (MemoryEditSessionViewModel) -> VoiceRecordingViewModel
    private let makeLocationPickerViewModel: LocationPickerViewModelFactory

    init(
        viewModel: MemoryDetailViewModel,
        makeVoiceRecordingViewModel: @escaping (MemoryEditSessionViewModel) -> VoiceRecordingViewModel,
        makeLocationPickerViewModel: @escaping LocationPickerViewModelFactory
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.makeVoiceRecordingViewModel = makeVoiceRecordingViewModel
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
                    togglePlayback: viewModel.togglePlayback
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
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .loaded(let memory) = viewModel.state {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit", systemImage: "pencil") {
                        editSession = viewModel.makeEditSession(for: memory)
                    }
                }
            }
        }
        .sheet(item: $editSession) { session in
            MemoryEditorSheet(
                session: session,
                recordingViewModel: makeVoiceRecordingViewModel(session),
                makeLocationPickerViewModel: makeLocationPickerViewModel
            ) {
                await viewModel.load()
            }
        }
        .task { await viewModel.load() }
        .onDisappear {
            Task { await viewModel.stopPlayback() }
        }
        .appScreenBackground()
    }

    private var navigationTitle: String {
        guard case .loaded(let memory) = viewModel.state else { return "Memory" }
        return memory.title
    }
}
