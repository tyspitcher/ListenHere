// Presents deliberate, accessible audio playback controls for one saved memory.

import Foundation
import SwiftUI

struct AudioPlaybackControls: View {
    let playbackState: AudioPlaybackState
    let togglePlayback: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ambient Sound", systemImage: "waveform")
                .font(.headline)

            switch playbackState {
            case .unavailable:
                Label("Audio unavailable", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            case .failed:
                Label("Couldn’t play this audio", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            case .ready(let duration):
                AudioPlaybackProgressView(
                    elapsed: 0,
                    duration: duration ?? 0,
                    buttonTitle: "Play Sound",
                    buttonImage: "play.fill",
                    togglePlayback: togglePlayback
                )
            case .playing(let elapsed, let duration):
                AudioPlaybackProgressView(
                    elapsed: elapsed,
                    duration: duration,
                    buttonTitle: "Pause Sound",
                    buttonImage: "pause.fill",
                    togglePlayback: togglePlayback
                )
            case .paused(let elapsed, let duration):
                AudioPlaybackProgressView(
                    elapsed: elapsed,
                    duration: duration,
                    buttonTitle: "Resume Sound",
                    buttonImage: "play.fill",
                    togglePlayback: togglePlayback
                )
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

}
