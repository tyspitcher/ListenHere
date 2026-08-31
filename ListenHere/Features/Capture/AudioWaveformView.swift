// Draws an accessible decorative waveform with optional playback progress highlighting.

import SwiftUI

struct AudioWaveformView: View {
    let samples: [Double]
    let progress: Double
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let visibleSamples = samples.isEmpty ? Array(repeating: 0.12, count: 32) : samples
            let spacing = 2.0
            let barWidth = max(1, (size.width - spacing * Double(visibleSamples.count - 1)) / Double(visibleSamples.count))
            let clampedProgress = min(1, max(0, progress))

            for (index, sample) in visibleSamples.enumerated() {
                let normalizedHeight = max(0.12, min(1, sample))
                let height = max(3, size.height * normalizedHeight)
                let x = Double(index) * (barWidth + spacing)
                let rect = CGRect(x: x, y: (size.height - height) / 2, width: barWidth, height: height)
                let isPlayed = (x + barWidth / 2) / max(size.width, 1) <= clampedProgress
                context.fill(
                    Path(roundedRect: rect, cornerRadius: barWidth / 2),
                    with: .color(isPlayed ? tint : tint.opacity(0.32))
                )
            }
        }
        .accessibilityHidden(true)
    }
}
