// Presents the deliberate audio action for a sound-only saved memory.

import Foundation
import SwiftUI

struct AudioPlaybackControls: View {
    let playbackState: AudioPlaybackState
    let togglePlayback: () -> Void

    var body: some View {
        switch playbackState {
        case .unavailable:
            Label("Audio unavailable", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        case .failed:
            Label("Couldn’t play this audio", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        case .ready:
            playbackButton(title: "Play Ambient Sound", systemImage: "speaker.slash.fill")
        case .playing:
            playbackButton(title: "Pause Ambient Sound", systemImage: "speaker.wave.2.fill")
        case .paused:
            playbackButton(title: "Play Ambient Sound", systemImage: "speaker.slash.fill")
        }
    }

    private func playbackButton(title: String, systemImage: String) -> some View {
        Button(title, systemImage: systemImage, action: togglePlayback)
            .buttonStyle(.borderedProminent)
    }
}
