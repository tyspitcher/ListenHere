// Presents the small, focused form for creating or renaming a journal.

import SwiftUI

struct JournalNameSheet: View {
    @Environment(\.dismiss) private var dismiss

    let editor: JournalNameEditor
    let save: (String) async -> Bool
    let cancel: () -> Void

    @State private var name: String
    @State private var isSaving = false
    @FocusState private var nameFieldIsFocused: Bool

    init(
        editor: JournalNameEditor,
        save: @escaping (String) async -> Bool,
        cancel: @escaping () -> Void
    ) {
        self.editor = editor
        self.save = save
        self.cancel = cancel
        _name = State(initialValue: editor.currentName ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Journal Name", text: $name)
                    .focused($nameFieldIsFocused)
                    .submitLabel(.done)
                    .onSubmit(saveJournal)
            }
            .navigationTitle(editor.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancelAndDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editor.saveTitle, action: saveJournal)
                        .disabled(normalizedName.isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.height(190)])
        .presentationDragIndicator(.visible)
        .task { nameFieldIsFocused = true }
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveJournal() {
        guard normalizedName.isEmpty == false, isSaving == false else { return }
        isSaving = true
        Task {
            if await save(name) { dismiss() }
            isSaving = false
        }
    }

    private func cancelAndDismiss() {
        cancel()
        dismiss()
    }
}

private extension JournalNameEditor {
    var title: String {
        switch self {
        case .create: "New Journal"
        case .rename: "Rename Journal"
        }
    }

    var saveTitle: String {
        switch self {
        case .create: "Create"
        case .rename: "Save"
        }
    }

    var currentName: String? {
        switch self {
        case .create: nil
        case .rename(let journal): journal.name
        }
    }
}
