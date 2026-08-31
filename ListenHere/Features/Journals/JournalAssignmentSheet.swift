// Presents native multi-selection for assigning one saved memory to one or more journals.

import SwiftUI

struct JournalAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedJournalIDs: Set<UUID>

    let journals: [JournalSummary]
    let applySelection: (Set<UUID>) -> Void

    init(
        journals: [JournalSummary],
        selectedJournalIDs: Set<UUID>,
        applySelection: @escaping (Set<UUID>) -> Void
    ) {
        self.journals = journals
        self.applySelection = applySelection
        _selectedJournalIDs = State(
            initialValue: selectedJournalIDs.intersection(journals.map(\.id))
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if journals.isEmpty {
                    ContentUnavailableView(
                        "No Journals",
                        systemImage: "books.vertical",
                        description: Text("Create a journal before changing this assignment.")
                    )
                } else {
                    List(journals) { journal in
                        Button {
                            toggle(journal.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(journal.name)
                                    if journal.isDefault {
                                        Text("Default Journal")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedJournalIDs.contains(journal.id) {
                                    Image(systemName: "checkmark")
                                        .bold()
                                        .accessibilityHidden(true)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .foregroundStyle(.primary)
                        .accessibilityValue(
                            selectedJournalIDs.contains(journal.id) ? "Selected" : "Not selected"
                        )
                    }
                }
            }
            .navigationTitle("Choose Journals")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if journals.isEmpty == false {
                    Text("Select at least one journal. A memory can appear in multiple journals.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.bar)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        applySelection(selectedJournalIDs)
                        dismiss()
                    }
                    .disabled(selectedJournalIDs.isEmpty)
                }
            }
        }
    }

    private func toggle(_ journalID: UUID) {
        if selectedJournalIDs.contains(journalID) {
            selectedJournalIDs.remove(journalID)
        } else {
            selectedJournalIDs.insert(journalID)
        }
    }
}
