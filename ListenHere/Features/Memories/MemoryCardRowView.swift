// Hosts a memory card whose title-row menu keeps contextual actions close to the memory name.

import SwiftUI

struct MemoryCardRowView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let memory: MemorySummary
    let managedPhotoURL: URL?
    let open: () -> Void
    let edit: () -> Void
    let chooseJournals: () -> Void
    let delete: () -> Void

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        MemoryCardView(
            memory: memory,
            managedPhotoURL: managedPhotoURL,
            open: open,
            edit: edit,
            chooseJournals: chooseJournals,
            delete: delete
        )
        .padding(14)
        .frame(maxWidth: maximumCardWidth, alignment: .leading)
        .background(palette.elevatedSurface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.10), radius: 10, y: 4)
    }

    private var maximumCardWidth: CGFloat {
        horizontalSizeClass == .regular ? 720 : .infinity
    }
}
