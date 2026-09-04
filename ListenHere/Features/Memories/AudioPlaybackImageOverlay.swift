// Keeps photo-associated audio playback immediately available without leaving the media canvas.

import Foundation
import SwiftUI

struct AudioPlaybackImageOverlay: View {
    let playbackState: AudioPlaybackState
    let togglePlayback: () -> Void

    var body: some View {
        switch playbackState {
        case .unavailable:
            status("Audio unavailable", systemImage: "exclamationmark.triangle")
        case .failed:
            status("Couldn’t play audio", systemImage: "exclamationmark.triangle")
        case .ready(let duration):
            playbackControl(elapsed: 0, duration: duration ?? 0, isPlaying: false)
        case .playing(let elapsed, let duration):
            playbackControl(elapsed: elapsed, duration: duration, isPlaying: true)
        case .paused(let elapsed, let duration):
            playbackControl(elapsed: elapsed, duration: duration, isPlaying: false)
        }
    }

    private func playbackControl(
        elapsed: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool
    ) -> some View {
        Button(action: togglePlayback) {
            HStack(spacing: 8) {
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .frame(width: 44, height: 44)

                Text("\(formattedTime(elapsed)) / \(formattedTime(duration))")
                    .font(.subheadline.monospacedDigit())
                    .lineLimit(1)
            }
            .padding(.trailing, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause ambient sound" : "Play ambient sound")
        .accessibilityValue("\(formattedTime(elapsed)) of \(formattedTime(duration))")
    }

    private func status(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
    }

    private func formattedTime(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
