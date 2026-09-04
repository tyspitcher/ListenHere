// Renders the loaded media, metadata, and deliberate audio controls for a saved memory.

import SwiftUI

struct MemoryDetailContentView: View {
    let memory: MemorySummary
    let photoURL: URL?
    let audioPlaybackState: AudioPlaybackState
    let togglePlayback: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
