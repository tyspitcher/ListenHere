// Explains the read-only state of a recently deleted journal and offers recovery in context.

import SwiftUI

struct DeletedJournalNotice: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let recover: () -> Void

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        VStack(alignment: .leading, spacing: 10) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("In Recently Deleted")
                        .font(.subheadline.weight(.semibold))
                    Text("Recover this journal to add or edit memories.")
                        .font(.footnote)
                }
            } icon: {
                Image(systemName: "trash")
            }

            Button("Recover Journal", systemImage: "arrow.uturn.backward", action: recover)
                .buttonStyle(.borderedProminent)
                .tint(recoveryButtonTint(palette: palette))
                .foregroundStyle(palette.primaryText)
        }
        .foregroundStyle(palette.primaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(palette.elevatedSurface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func recoveryButtonTint(palette: AppPalette) -> Color {
        colorScheme == .light
            ? palette.secondaryAccent.opacity(0.28)
            : palette.secondaryAccent
    }
}
