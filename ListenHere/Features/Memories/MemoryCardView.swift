// Renders a reusable media-first card with memory title, caption, location, and audio metadata.

import SwiftUI

struct MemoryCardView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let memory: MemorySummary
    let managedPhotoURL: URL?
    let open: () -> Void
    let edit: () -> Void
    let chooseJournals: () -> Void
    let delete: () -> Void

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        VStack(alignment: .leading, spacing: 14) {
            media

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(memory.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.primaryText)

                    Spacer(minLength: 0)

                    MemoryCardActionMenu(
                        edit: edit,
                        chooseJournals: chooseJournals,
                        delete: delete
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    if let caption = memory.caption {
                        Text(caption)
                            .font(.body)
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(3)
                    }

                    metadata
                }
            }
        }
        // The card's media is sized from the available list width. Keep that width on the
        // layout root as well, so LazyVStack measures the same bounds it visually renders.
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .onTapGesture(perform: open)
        .accessibilityHint("Opens memory details")
        .accessibilityValue(memory.hasAudio ? "Includes ambient sound" : "")
    }

    @ViewBuilder
    private var media: some View {
        let palette = theme.palette(for: colorScheme)
        // The base establishes the card's finite size. Overlay content cannot enlarge
        // that size, so even extremely wide panoramas remain inside the list row.
        Color.clear
        .frame(maxWidth: .infinity)
        .aspectRatio(4 / 3, contentMode: .fit)
        .background(palette.surface)
        .overlay {
            Group {
                switch memory.thumbnail {
                case .previewAsset(let name):
                    Image(name)
                        .resizable()
                        .scaledToFill()
                case .managedFile:
                    if let managedPhotoURL {
                        ManagedPhotoImageView(
                            photoURL: managedPhotoURL,
                            contentMode: .fill,
                            maximumPixelSize: 700
                        )
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 42))
                            .foregroundStyle(palette.accent)
                    }
                case nil:
                    Image(systemName: memory.hasAudio ? "waveform" : "photo")
                        .font(.system(size: 42))
                        .foregroundStyle(palette.accent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .bottomTrailing) {
            if memory.hasAudio {
                Image(systemName: "waveform")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(10)
                    .accessibilityHidden(true)
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }

    private var metadata: some View {
        let palette = theme.palette(for: colorScheme)
        return VStack(alignment: .leading, spacing: 5) {
            Label {
                Text(memory.capturedAt, format: .dateTime.month(.abbreviated).day().year())
            } icon: {
                Image(systemName: "calendar")
            }

            if let location = memory.location {
                LocationDescriptionView(location: location)
            }

            if memory.journalNames.isEmpty == false {
                Label(memory.journalNames.joined(separator: ", "), systemImage: "book.closed")
            }
        }
        .font(.subheadline)
        .foregroundStyle(palette.secondaryText)
    }

}
