// Presents native multi-selection for assigning one saved memory to one or more journals.

import SwiftUI

struct JournalAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var journals: [JournalSummary]
    @State private var selectedJournalIDs: Set<UUID>
    @State private var isApplyingSelection = false
    @State private var errorMessage: String?

    let applySelection: (Set<UUID>) async -> Bool
    let createJournal: ((String) async -> JournalSummary?)?

    init(
        journals: [JournalSummary],
        selectedJournalIDs: Set<UUID>,
        createJournal: ((String) async -> JournalSummary?)? = nil,
        applySelection: @escaping (Set<UUID>) async -> Bool
    ) {
        _journals = State(initialValue: journals)
        self.applySelection = applySelection
        self.createJournal = createJournal
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
                if let createJournal {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            JournalCreationForm(
                                createJournal: createJournal,
                                didCreate: addAndSelect
                            )
                        } label: {
                            Label("New Journal", systemImage: "plus")
                        }
                    }
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

    private func addAndSelect(_ journal: JournalSummary) {
        if journals.contains(where: { $0.id == journal.id }) == false {
            journals.append(journal)
            journals.sort { first, second in
                if first.isDefault != second.isDefault { return first.isDefault }
                return first.name.localizedStandardCompare(second.name) == .orderedAscending
            }
        }
        selectedJournalIDs.insert(journal.id)
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

private struct JournalCreationForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @FocusState private var nameFieldIsFocused: Bool

    let createJournal: (String) async -> JournalSummary?
    let didCreate: (JournalSummary) -> Void

    var body: some View {
        Form {
            TextField("Journal Name", text: $name)
                .focused($nameFieldIsFocused)
                .submitLabel(.done)
                .onSubmit(create)
        }
        .navigationTitle("New Journal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create", action: create)
                    .disabled(normalizedName.isEmpty || isCreating)
            }
        }
        .task { nameFieldIsFocused = true }
        .alert("Couldn’t Create Journal", isPresented: errorIsPresented) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if $0 == false { errorMessage = nil } }
        )
    }

    private func create() {
        guard normalizedName.isEmpty == false, isCreating == false else { return }
        isCreating = true
        Task {
            guard let journal = await createJournal(normalizedName) else {
                isCreating = false
                errorMessage = "The journal couldn’t be created. Try again."
                return
            }
            didCreate(journal)
            dismiss()
        }
    }
}
