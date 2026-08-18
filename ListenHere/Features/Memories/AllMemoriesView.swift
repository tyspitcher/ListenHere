import SwiftUI

struct AllMemoriesView: View {
    @State private var viewModel: AllMemoriesViewModel
    @State private var captureSheetIsPresented = false
    @State private var memoryPendingDeletion: MemorySummary?

    let openLibrary: () -> Void
    let openMemory: (UUID) -> Void

    init(
        viewModel: AllMemoriesViewModel,
        openLibrary: @escaping () -> Void,
        openMemory: @escaping (UUID) -> Void
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.openLibrary = openLibrary
        self.openMemory = openMemory
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("Loading Memories")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let memories) where memories.isEmpty:
                ContentUnavailableView {
                    Label("No Memories Yet", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text("Capture a photo, a sound, or both to hold on to this moment.")
                } actions: {
                    Button("Create Memory", systemImage: "plus") {
                        captureSheetIsPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .loaded(let memories):
                memoryList(memories)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Memories Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { viewModel.load() }
                }
            }
        }
        .navigationTitle("All Memories")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: openLibrary) {
                    Label("Library", systemImage: "square.grid.2x2")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    captureSheetIsPresented = true
                } label: {
                    Label("New Memory", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $captureSheetIsPresented) {
            CaptureSourceSheet()
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
        .task { viewModel.load() }
        .appScreenBackground()
    }

    private func memoryList(_ memories: [MemorySummary]) -> some View {
        ScrollView {
            LazyVStack(spacing: 22) {
                ForEach(memories) { memory in
                    Button {
                        openMemory(memory.id)
                    } label: {
                        MemoryCardView(memory: memory)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            memoryPendingDeletion = memory
                        }
                    }
                    .accessibilityHint("Opens memory details")
                }
            }
            .padding()
        }
        .refreshable { viewModel.load() }
    }

    private var deletionIsPresented: Binding<Bool> {
        Binding(
            get: { memoryPendingDeletion != nil },
            set: { if $0 == false { memoryPendingDeletion = nil } }
        )
    }
}

#if DEBUG
#Preview("Populated") {
    NavigationStack {
        AllMemoriesView(
            viewModel: AllMemoriesViewModel(repository: PreviewMemoryRepository()),
            openLibrary: {},
            openMemory: { _ in }
        )
    }
    .appTheme(.listenHere)
}

#Preview("Empty") {
    NavigationStack {
        AllMemoriesView(
            viewModel: AllMemoriesViewModel(repository: PreviewMemoryRepository(memories: [])),
            openLibrary: {},
            openMemory: { _ in }
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
            openMemory: { _ in }
        )
    }
    .appTheme(.listenHere)
}

#Preview("Dark, Large Type") {
    NavigationStack {
        AllMemoriesView(
            viewModel: AllMemoriesViewModel(repository: PreviewMemoryRepository()),
            openLibrary: {},
            openMemory: { _ in }
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
            openMemory: { _ in }
        )
    }
    .appTheme(.listenHere)
    .frame(width: 834, height: 1_194)
}
#endif
