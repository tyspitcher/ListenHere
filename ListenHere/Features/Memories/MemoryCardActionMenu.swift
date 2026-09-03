// Presents contextual actions for a saved memory without making the card's navigation affordance ambiguous.

import SwiftUI

struct MemoryCardActionMenu: View {
    let edit: () -> Void
    let chooseJournals: () -> Void
    let delete: () -> Void

    var body: some View {
        Menu {
            Button("Edit", systemImage: "pencil", action: edit)
            Button("Choose Journals", systemImage: "books.vertical", action: chooseJournals)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: delete)
        } label: {
            Label("Memory Actions", systemImage: "ellipsis")
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Memory Actions")
        .accessibilityHint("Edit, choose journals, or move this memory to Recently Deleted")
    }
}
