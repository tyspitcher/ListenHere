import SwiftUI

struct JournalsView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: JournalsViewModel

    init(viewModel: JournalsViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Loading Journals")
            case .loaded(let journals) where journals.isEmpty:
                ContentUnavailableView(
                    "No Journals Yet",
                    systemImage: "book.closed",
                    description: Text("Your first journal will be created when you save a memory.")
                )
            case .loaded(let journals):
                List(journals) { journal in
                    NavigationLink(value: AppRoute.journal(journal.id)) {
                        Label {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(journal.name)
                                    if journal.isDefault {
                                        Text("Default Journal")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(journal.memoryCount, format: .number)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: journal.isSystemUnassigned ? "tray" : "book.closed")
                                .foregroundStyle(
                                    journal.isDefault ? palette.accent : palette.secondaryAccent
                                )
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if journal.isSystemUnassigned == false {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                viewModel.requestDeletion(of: journal)
                            }
                        }
                    }
                }
            case .failed(let message):
                ContentUnavailableView(
                    "Journals Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            }
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Journals")
        .task { await viewModel.load() }
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
            "Journal Not Deleted",
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
}
