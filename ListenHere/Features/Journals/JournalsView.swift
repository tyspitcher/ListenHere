// Renders the journal collection list and owns native creation, editing, and deletion presentation.
import SwiftUI

struct JournalsView: View {
    @State private var viewModel: JournalsViewModel

    init(viewModel: JournalsViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        JournalsContentView(viewModel: viewModel)
        .navigationTitle("Journals")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Journal", systemImage: "plus") {
                    viewModel.requestJournalCreation()
                }
            }
        }
        .sheet(item: nameEditorBinding) { editor in
            JournalNameSheet(
                editor: editor,
                save: viewModel.saveJournalName,
                cancel: viewModel.dismissNameEditor
            )
        }
        .confirmationDialog(
            deletionTitle,
            isPresented: deletionConfirmationBinding,
            titleVisibility: .visible,
            presenting: viewModel.journalPendingDeletion
        ) { journal in
            if journal.memoryCount == 0 {
                Button("Delete Journal", role: .destructive) {
                    Task { await viewModel.deleteJournalAndMemories() }
                }
            } else {
                Button("Delete Journal Only", role: .destructive) {
                    viewModel.prepareToMoveMemories()
                }
                Button("Delete Journal & Memories", role: .destructive) {
                    Task { await viewModel.deleteJournalAndMemories() }
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelDeletion()
            }
        } message: { journal in
            if journal.memoryCount > 0 {
                Text(
                    "If you delete the journal only, you’ll be prompted to move its memories " +
                    "to another journal. Deleting the journal and memories moves all contained " +
                    "memories to Recently Deleted, including memories shared with other journals."
                )
            }
        }
        .sheet(item: moveRequestBinding) { request in
            MoveMemoriesBeforeDeletingView(request: request, viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(viewModel.isPerformingDeletion)
        }
        .alert(
            "Couldn’t Update Journal",
            isPresented: errorBinding,
            actions: {
                Button("OK") { viewModel.dismissError() }
            },
            message: {
                Text(viewModel.errorMessage ?? "This journal couldn’t be deleted. Try again.")
            }
        )
    }

    private var deletionTitle: String {
        guard let journal = viewModel.journalPendingDeletion else { return "Delete Journal?" }
        return "Delete “\(journal.name)” Journal?"
    }

    private var deletionConfirmationBinding: Binding<Bool> {
        Binding(
            get: { viewModel.journalPendingDeletion != nil },
            set: { isPresented in
                if isPresented == false { viewModel.cancelDeletion() }
            }
        )
    }

    private var moveRequestBinding: Binding<JournalMoveRequest?> {
        Binding(
            get: { viewModel.moveRequest },
            set: { request in
                if request == nil { viewModel.dismissMoveRequest() }
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if isPresented == false { viewModel.dismissError() }
            }
        )
    }

    private var nameEditorBinding: Binding<JournalNameEditor?> {
        Binding(
            get: { viewModel.nameEditor },
            set: { editor in
                if editor == nil { viewModel.dismissNameEditor() }
            }
        )
    }
}
