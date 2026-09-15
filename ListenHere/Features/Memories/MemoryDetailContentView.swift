// Renders the loaded media, metadata, and deliberate audio controls for a saved memory.

import SwiftUI

struct MemoryDetailContentView: View {
    let memory: MemorySummary
    let photoURL: URL?
    let audioPlaybackState: AudioPlaybackState
    let isRecentlyDeleted: Bool
    let recoverMemory: () -> Void
    let togglePlayback: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isRecentlyDeleted {
                    RecentlyDeletedMemoryNotice(recover: recoverMemory)
                }

                if memory.thumbnail != nil {
                    MemoryDetailPhotoView(thumbnail: memory.thumbnail, photoURL: photoURL)
                        .overlay(alignment: .bottomTrailing) {
                            if memory.hasAudio {
                                AudioPlaybackImageOverlay(
                                    playbackState: audioPlaybackState,
                                    togglePlayback: togglePlayback
                                )
                                .padding(12)
                            }
                        }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(memory.title)
                        .font(.title.bold())

                    if let caption = memory.caption {
                        Text(caption)
                            .font(.body)
                    }

                    Label {
                        Text(memory.capturedAt, format: .dateTime.month(.wide).day().year())
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    if let location = memory.location {
                        LocationDescriptionView(location: location)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if memory.hasAudio, memory.thumbnail == nil {
                    AudioPlaybackControls(
                        playbackState: audioPlaybackState,
                        togglePlayback: togglePlayback
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RecentlyDeletedMemoryNotice: View {
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
                    Text("Recover this memory to make changes.")
                        .font(.footnote)
                }
            } icon: {
                Image(systemName: "trash")
            }

            Button("Recover", systemImage: "arrow.uturn.backward", action: recover)
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
