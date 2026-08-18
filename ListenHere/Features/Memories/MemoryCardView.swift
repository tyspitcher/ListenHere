import SwiftUI

struct MemoryCardView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let memory: MemorySummary

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
        .background(palette.elevatedSurface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.10), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var media: some View {
        switch memory.thumbnail {
        case .previewAsset(let name):
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
        case .managedFile:
            mediaPlaceholder(systemImage: "photo")
        case nil:
            mediaPlaceholder(systemImage: memory.hasAudio ? "waveform" : "photo")
        }
    }

    private func mediaPlaceholder(systemImage: String) -> some View {
        let palette = theme.palette(for: colorScheme)
        return ZStack {
            palette.surface
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(palette.accent)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(4 / 3, contentMode: .fit)
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
}
