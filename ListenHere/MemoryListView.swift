import SwiftUI

struct MemoryListView: View {
    @State private var viewModel: JournalDetailViewModel

    init(viewModel: JournalDetailViewModel) {
        _viewModel = State(wrappedValue: viewModel)
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
                                MemoryCardView(memory: memory)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            case .loading:
                ProgressView("Loading Journal")
            }
        }
        .navigationTitle("Journal")
        .task { await viewModel.load() }
        .appScreenBackground()
    }
}
