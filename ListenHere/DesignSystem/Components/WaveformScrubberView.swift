// Makes the waveform a direct-manipulation playback position control.

import SwiftUI

struct WaveformScrubberView: View {
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var availableWidth = 0.0

    let samples: [Double]
    let progress: Double
    let elapsed: TimeInterval
    let duration: TimeInterval
    let tint: Color
    let isEnabled: Bool
    let seek: (Double) -> Void

    var body: some View {
        ZStack {
            AudioWaveformView(samples: samples, progress: progress, tint: tint)
        }
        .frame(height: 32)
        .frame(minHeight: 44)
        .contentShape(.rect)
        .onGeometryChange(for: Double.self) { proxy in
            proxy.size.width
        } action: { width in
            availableWidth = width
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    seek(to: value.location.x)
                }
        )
        .allowsHitTesting(isEnabled)
        .accessibilityElement()
        .accessibilityHidden(isEnabled == false)
        .accessibilityLabel("Playback position")
        .accessibilityValue(
            "\(Self.formattedTime(elapsed)) of \(Self.formattedTime(duration))"
        )
        .accessibilityHint("Swipe up or down to seek by 10 seconds.")
        .accessibilityInputLabels(["Playback position", "Audio position"])
        .accessibilityAdjustableAction(adjustPlaybackPosition)
    }

    private func seek(to horizontalPosition: Double) {
        guard isEnabled, availableWidth > 0 else { return }
        let visualProgress = min(max(0, horizontalPosition / availableWidth), 1)
        seek(layoutDirection == .rightToLeft ? 1 - visualProgress : visualProgress)
    }

    private func adjustPlaybackPosition(_ direction: AccessibilityAdjustmentDirection) {
        guard isEnabled, duration > 0 else { return }
        let adjustment = min(10, duration)
        let targetTime: TimeInterval
        switch direction {
        case .increment:
            targetTime = elapsed + adjustment
        case .decrement:
            targetTime = elapsed - adjustment
        @unknown default:
            return
        }
        seek(min(max(0, targetTime), duration) / duration)
    }

    private static func formattedTime(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return seconds < 10 ? "\(minutes):0\(seconds)" : "\(minutes):\(seconds)"
    }
}
