// Displays memories belonging to the selected journal-detail route.
import SwiftUI

struct MemoryListView: View {
    @State private var viewModel: JournalDetailViewModel
    @State private var captureViewModel: CaptureViewModel?

    private let makeCaptureViewModel: () -> CaptureViewModel
    private let makeVoiceRecordingViewModel: (CaptureViewModel) -> VoiceRecordingViewModel
    private let makeCaptureMediaPreviewViewModel: (CaptureViewModel) -> CaptureMediaPreviewViewModel
    private let makeCameraCaptureViewModel: () -> CameraCaptureViewModel

    init(
        viewModel: JournalDetailViewModel,
        makeCaptureViewModel: @escaping () -> CaptureViewModel,
        makeVoiceRecordingViewModel: @escaping (CaptureViewModel) -> VoiceRecordingViewModel,
        makeCaptureMediaPreviewViewModel: @escaping (CaptureViewModel) -> CaptureMediaPreviewViewModel,
        makeCameraCaptureViewModel: @escaping () -> CameraCaptureViewModel
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.makeCaptureViewModel = makeCaptureViewModel
        self.makeVoiceRecordingViewModel = makeVoiceRecordingViewModel
        self.makeCaptureMediaPreviewViewModel = makeCaptureMediaPreviewViewModel
        self.makeCameraCaptureViewModel = makeCameraCaptureViewModel
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
                            NavigationLink(value: AppRoute.memory(memory.id)) {
                                MemoryCardView(
                                    memory: memory,
                                    managedPhotoURL: viewModel.managedPhotoURL(for: memory)
                                )
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                }
            case .loading:
                ProgressView("Loading Journal")
            }
        }
        .navigationTitle("Journal")
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
                onSaved: finishCapture
            )
            .id(captureViewModel.id)
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
}
