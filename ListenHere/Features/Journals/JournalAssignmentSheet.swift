// Presents native multi-selection for assigning one saved memory to one or more journals.

import SwiftUI

struct JournalAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedJournalIDs: Set<UUID>
    @State private var isApplyingSelection = false
    @State private var errorMessage: String?

    let journals: [JournalSummary]
    let applySelection: (Set<UUID>) async -> Bool

    init(
        journals: [JournalSummary],
        selectedJournalIDs: Set<UUID>,
        applySelection: @escaping (Set<UUID>) async -> Bool
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
                        apply()
                    }
                    .disabled(selectedJournalIDs.isEmpty || isApplyingSelection)
                }
            }
        }
        .alert("Couldn’t Update Journals", isPresented: errorIsPresented) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private func toggle(_ journalID: UUID) {
        if selectedJournalIDs.contains(journalID) {
            selectedJournalIDs.remove(journalID)
        } else {
            selectedJournalIDs.insert(journalID)
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if $0 == false { errorMessage = nil } }
        )
    }

    private func apply() {
        guard isApplyingSelection == false else { return }
        isApplyingSelection = true
        Task {
            guard await applySelection(selectedJournalIDs) else {
                isApplyingSelection = false
                errorMessage = "The journal assignments couldn’t be updated. Please try again."
                return
            }
            dismiss()
        }
    }
}
