// Presents the shared, compact playback treatment used anywhere ambient sound can be played.

import SwiftUI

struct AudioWaveformPlayerView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let samples: [Double]
    let playbackState: AudioPlaybackState
    let togglePlayback: () -> Void
    let seek: (Double) -> Void
    var removeAudio: (() -> Void)?

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        HStack(spacing: 10) {
            Button(playbackButtonTitle, systemImage: playbackButtonImage, action: togglePlayback)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(playbackIsUnavailable)

            WaveformScrubberView(
                samples: samples,
                progress: playbackProgress,
                elapsed: elapsedTime,
                duration: totalDuration,
                tint: palette.secondaryAccent,
                isEnabled: playbackIsUnavailable == false,
                seek: seek
            )
            .frame(maxWidth: .infinity)

            Text(playbackTimeDescription)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let removeAudio {
                Button("Remove Sound", systemImage: "trash", action: removeAudio)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(palette.destructive)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var playbackProgress: Double {
        switch playbackState {
        case .playing(let elapsed, let duration), .paused(let elapsed, let duration):
            duration > 0 ? elapsed / duration : 0
        case .unavailable, .failed, .ready:
            0
        }
    }

    private var playbackButtonTitle: String {
        if case .playing = playbackState { "Pause Sound" } else { "Play Sound" }
    }

    private var elapsedTime: TimeInterval {
        switch playbackState {
        case .playing(let elapsed, _), .paused(let elapsed, _):
            elapsed
        case .unavailable, .failed, .ready:
            0
        }
    }

    private var totalDuration: TimeInterval {
        switch playbackState {
        case .ready(let duration):
            duration ?? 0
        case .playing(_, let duration), .paused(_, let duration):
            duration
        case .unavailable, .failed:
            0
        }
    }

    private var playbackButtonImage: String {
        if case .playing = playbackState { "pause.fill" } else { "play.fill" }
    }

    private var playbackIsUnavailable: Bool {
        switch playbackState {
        case .unavailable, .failed:
            true
        case .ready, .playing, .paused:
            false
        }
    }

    private var playbackTimeDescription: String {
        switch playbackState {
        case .ready(let duration):
            "0:00 / \(Self.formattedTime(duration ?? 0))"
        case .playing(let elapsed, let duration), .paused(let elapsed, let duration):
            "\(Self.formattedTime(elapsed)) / \(Self.formattedTime(duration))"
        case .unavailable:
            "Unavailable"
        case .failed:
            "Failed"
        }
    }

    private static func formattedTime(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return seconds < 10 ? "\(minutes):0\(seconds)" : "\(minutes):\(seconds)"
    }
}
