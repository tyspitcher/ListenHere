// Renders a reusable media-first card with memory title, caption, location, and audio metadata.

import SwiftUI

struct MemoryCardView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let memory: MemorySummary
    let managedPhotoURL: URL?

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        VStack(alignment: .leading, spacing: 14) {
            media

            VStack(alignment: .leading, spacing: 8) {
                Text(memory.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                if let caption = memory.caption {
                    Text(caption)
                        .font(.body)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(3)
                }

                metadata
            }
        }
        .padding(14)
        .frame(maxWidth: maximumCardWidth, alignment: .leading)
        .background(palette.elevatedSurface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.10), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
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

            if let locationName = memory.locationName {
                Label(locationName, systemImage: "location")
            }

            if memory.hasAudio {
                Label(audioLabel, systemImage: "waveform")
            }

            if memory.journalNames.isEmpty == false {
                Label(memory.journalNames.joined(separator: ", "), systemImage: "book.closed")
            }
        }
        .font(.subheadline)
        .foregroundStyle(palette.secondaryText)
    }

    private var audioLabel: String {
        guard let duration = memory.audioDurationSeconds else { return "Includes sound" }
        let seconds = max(0, Int(duration.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var maximumCardWidth: CGFloat {
        horizontalSizeClass == .regular ? 720 : .infinity
    }
}
