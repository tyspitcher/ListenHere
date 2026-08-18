import SwiftUI

struct MoveMemoriesBeforeDeletingView: View {
    @Environment(\.dismiss) private var dismiss

    let request: JournalMoveRequest
    let viewModel: JournalsViewModel

    @State private var selectedDestinationID: UUID?

    init(request: JournalMoveRequest, viewModel: JournalsViewModel) {
        self.request = request
        self.viewModel = viewModel
        _selectedDestinationID = State(initialValue: request.destinations.first?.id)
    }

    var body: some View {
        NavigationStack {
            Group {
                if request.destinations.isEmpty {
                    ContentUnavailableView(
                        "No Other Journals",
                        systemImage: "book.closed",
                        description: Text(
                            "Create another journal before deleting this journal alone."
                        )
                    )
                } else {
                    Form {
                        Section {
                            Picker("Journal", selection: $selectedDestinationID) {
                                ForEach(request.destinations) { journal in
                                    Label(
                                        journal.name,
                                        systemImage: journal.isDefault ? "book.closed.fill" : "book.closed"
                                    )
                                    .tag(Optional(journal.id))
                                }
                            }
                        } header: {
                            Text("Move Memories")
                        } footer: {
                            Text(moveSummary)
                        }

                        Section {
                            Button {
                                Task { await moveMemories() }
                            } label: {
                                HStack {
                                    Spacer()
                                    if viewModel.isPerformingDeletion {
                                        ProgressView()
                                    } else {
                                        Text("Move Memories & Delete Journal")
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(selectedDestinationID == nil || viewModel.isPerformingDeletion)
                        }
                    }
                }
            }
            .navigationTitle("Move Memories")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                Text(
                    "Choose a new location for memories from the “\(request.journal.name)” journal."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isPerformingDeletion)
                }
            }
        }
    }

    private var selectedDestination: JournalSummary? {
        request.destinations.first { $0.id == selectedDestinationID }
    }

    private var moveSummary: String {
        guard let selectedDestination else { return "Choose a destination journal." }
        let noun = request.journal.memoryCount == 1 ? "memory" : "memories"
        return "\(request.journal.memoryCount) \(noun) will be moved to \(selectedDestination.name)."
    }

    private func moveMemories() async {
        guard let selectedDestinationID else { return }
        if await viewModel.moveMemoriesAndDeleteJournal(destinationID: selectedDestinationID) {
            dismiss()
        }
    }
}

#if DEBUG
#Preview("Move Memories") {
    let source = JournalSummary(
        id: UUID(),
        name: "Summer in the Tetons",
        memoryCount: 3,
        isDefault: false,
        isSystemUnassigned: false
    )
    let everyday = JournalSummary(
        id: UUID(),
        name: "Everyday",
        memoryCount: 18,
        isDefault: true,
        isSystemUnassigned: false
    )
    let family = JournalSummary(
        id: UUID(),
        name: "Family",
        memoryCount: 12,
        isDefault: false,
        isSystemUnassigned: false
    )
    let repository = ConfigurablePreviewJournalRepository(
        journals: [source, everyday, family]
    )

    MoveMemoriesBeforeDeletingView(
        request: JournalMoveRequest(
            journal: source,
            destinations: [everyday, family]
        ),
        viewModel: JournalsViewModel(repository: repository)
    )
}

#Preview("No Destination") {
    let source = JournalSummary(
        id: UUID(),
        name: "Only Journal",
        memoryCount: 1,
        isDefault: true,
        isSystemUnassigned: false
    )
    let repository = ConfigurablePreviewJournalRepository(journals: [source])

    MoveMemoriesBeforeDeletingView(
        request: JournalMoveRequest(journal: source, destinations: []),
        viewModel: JournalsViewModel(repository: repository)
    )
}
#endif
