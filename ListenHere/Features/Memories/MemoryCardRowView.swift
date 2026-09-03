// Combines card navigation with a separate native menu so each action remains individually accessible.

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

        VStack(alignment: .leading, spacing: 8) {
            Button(action: open) {
                MemoryCardView(memory: memory, managedPhotoURL: managedPhotoURL)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .accessibilityHint("Opens memory details")

            HStack {
                Spacer()
                MemoryCardActionMenu(
                    edit: edit,
                    chooseJournals: chooseJournals,
                    delete: delete
                )
            }
        }
        .padding(14)
        .frame(maxWidth: maximumCardWidth, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .background(palette.elevatedSurface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.10), radius: 10, y: 4)
    }

    private var maximumCardWidth: CGFloat {
        horizontalSizeClass == .regular ? 720 : .infinity
    }
}
