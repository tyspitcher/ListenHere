// Presents the existing journal picker after loading the journals available for a saved memory.

import SwiftUI

struct MemoryJournalAssignmentSheet: View {
    @State private var viewModel: MemoryJournalAssignmentViewModel

    let onUpdated: () -> Void

    init(viewModel: MemoryJournalAssignmentViewModel, onUpdated: @escaping () -> Void) {
        _viewModel = State(wrappedValue: viewModel)
        self.onUpdated = onUpdated
    }

    var body: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("Loading Journals")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await viewModel.load() }
        case .loaded:
            JournalAssignmentSheet(
                journals: viewModel.journals,
                selectedJournalIDs: viewModel.selectedJournalIDs,
                createJournal: viewModel.createJournal,
                applySelection: applySelection
            )
        case .failed:
            ContentUnavailableView {
                Label("Journals Unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Try loading the journals again before changing this memory.")
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.load() }
                }
            }
            .task { await viewModel.load() }
        }
    }

    private func applySelection(_ journalIDs: Set<UUID>) async -> Bool {
        let didUpdate = viewModel.applySelection(journalIDs)
        if didUpdate {
            onUpdated()
        }
        return didUpdate
    }
}
