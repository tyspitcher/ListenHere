import SwiftUI

struct MemoryDetailView: View {
    @State private var viewModel: MemoryDetailViewModel

    init(viewModel: MemoryDetailViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loaded(let memory):
                ScrollView {
                    MemoryCardView(memory: memory)
                        .padding()
                }
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
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .appScreenBackground()
    }

    private var navigationTitle: String {
        guard case .loaded(let memory) = viewModel.state else { return "Memory" }
        return memory.title
    }
}
