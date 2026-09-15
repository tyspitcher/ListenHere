// Presents contextual actions for a saved memory without making the card's navigation affordance ambiguous.

import SwiftUI

struct MemoryCardActionMenu: View {
    @State private var isDeletionConfirmationPresented = false

    let memoryTitle: String
    let edit: () -> Void
    let chooseJournals: () -> Void
    let delete: () -> Void

    var body: some View {
        Menu {
            Button("Edit", systemImage: "pencil", action: edit)
            Button("Choose Journals", systemImage: "books.vertical", action: chooseJournals)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) {
                isDeletionConfirmationPresented = true
            }
        } label: {
            Label("Memory Actions", systemImage: "ellipsis")
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Memory Actions")
        .accessibilityHint("Edit, choose journals, or move this memory to Recently Deleted")
        // Keep this presentation on the menu that initiated it. iOS presents it as a reachable
        // action sheet on compact devices and anchors it to this memory's action control on iPad.
        .confirmationDialog(
            "Move “\(memoryTitle)” to Recently Deleted?",
            isPresented: $isDeletionConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Move to Recently Deleted", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can recover this memory for 30 days.")
        }
    }
}
