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
                MemoryDetailPhotoView(thumbnail: memory.thumbnail, photoURL: photoURL)

                VStack(alignment: .leading, spacing: 10) {
                    Text(memory.title)
                        .font(.title.bold())

                    if let caption = memory.caption {
                        Text(caption)
                            .font(.body)
                    }

                    Label {
                        Text(memory.capturedAt, format: .dateTime.month(.wide).day().year().hour().minute())
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    if let locationName = memory.locationName {
                        Label(locationName, systemImage: "location")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if memory.hasAudio {
                    AudioPlaybackControls(
                        playbackState: audioPlaybackState,
                        togglePlayback: togglePlayback
                    )
                }
            }
            .padding()
        }
    }
}
