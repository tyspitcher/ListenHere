// Draws accessible waveform previews and a responsive live recording meter.

import SwiftUI

struct AudioWaveformView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let samples: [WaveformSample]
    private let progress: Double
    private let tint: Color
    private let style: Style

    init(samples: [Double], progress: Double, tint: Color) {
        self.samples = samples.suffix(Self.recordedSampleCount).map {
            WaveformSample(average: $0, peak: $0)
        }
        self.progress = progress
        self.tint = tint
        style = .recorded
    }

    init(liveSamples: [AudioMeterLevel], tint: Color) {
        samples = liveSamples.suffix(Self.recordedSampleCount).map {
            WaveformSample(average: $0.average, peak: $0.peak)
        }
        progress = 1
        self.tint = tint
        style = .live
    }

    var body: some View {
        Group {
            if style == .live, reduceMotion == false {
                TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
                    waveformCanvas(pulse: Self.pulse(for: timeline.date))
                }
            } else {
                waveformCanvas(pulse: 1)
            }
        }
        .accessibilityHidden(true)
    }

    private func waveformCanvas(pulse: Double) -> some View {
        Canvas { context, size in
            let visibleSamples = displaySamples
            let usesRecordingVisualLanguage = style != .playback
            let spacing = usesRecordingVisualLanguage ? 3.0 : 2.0
            let barWidth = max(1, (size.width - spacing * Double(visibleSamples.count - 1)) / Double(visibleSamples.count))
            let clampedProgress = min(1, max(0, progress))

            for (index, sample) in visibleSamples.enumerated() {
                let x = Double(index) * (barWidth + spacing)
                let isPlayed = (x + barWidth / 2) / max(size.width, 1) <= clampedProgress
                let emphasis = usesRecordingVisualLanguage ? Double(index + 1) / Double(visibleSamples.count) : 1
                let averageHeight = Self.barHeight(
                    for: sample.average,
                    in: size.height,
                    live: usesRecordingVisualLanguage
                )
                let averageRect = CGRect(
                    x: x,
                    y: (size.height - averageHeight) / 2,
                    width: barWidth,
                    height: averageHeight
                )
                let opacity: Double
                switch style {
                case .live:
                    opacity = 0.35 + 0.65 * emphasis
                case .recorded:
                    opacity = isPlayed ? 0.55 + 0.45 * emphasis : 0.18 + 0.25 * emphasis
                case .playback:
                    opacity = isPlayed ? 1 : 0.32
                }
                context.fill(
                    Path(roundedRect: averageRect, cornerRadius: barWidth / 2),
                    with: .color(tint.opacity(opacity))
                )

                guard style == .live else { continue }
                let peakHeight = Self.barHeight(for: sample.peak, in: size.height, live: true)
                let peakWidth = max(1, barWidth * 0.42)
                let peakRect = CGRect(
                    x: x + (barWidth - peakWidth) / 2,
                    y: (size.height - peakHeight) / 2,
                    width: peakWidth,
                    height: peakHeight
                )
                let isLatestSample = index == visibleSamples.indices.last
                let peakOpacity = isLatestSample ? 0.6 + 0.4 * pulse : 0.35 + 0.4 * emphasis
                context.fill(
                    Path(roundedRect: peakRect, cornerRadius: peakWidth / 2),
                    with: .color(tint.opacity(peakOpacity))
                )
            }
        }
    }

    private var displaySamples: [WaveformSample] {
        if samples.isEmpty {
            return Array(
                repeating: .quiet,
                count: style == .playback ? 32 : Self.recordedSampleCount
            )
        }

        guard style != .playback, samples.count < Self.recordedSampleCount else { return samples }
        return Array(repeating: .quiet, count: Self.recordedSampleCount - samples.count) + samples
    }

    private static let recordedSampleCount = 36

    private static func barHeight(for amplitude: Double, in availableHeight: CGFloat, live: Bool) -> CGFloat {
        let clampedAmplitude = max(0, min(1, amplitude))
        let responsiveAmplitude = live ? pow(clampedAmplitude, 0.45) : clampedAmplitude
        return max(3, availableHeight * max(0.12, responsiveAmplitude))
    }

    private static func pulse(for date: Date) -> Double {
        0.5 + 0.5 * sin(date.timeIntervalSinceReferenceDate * .pi * 2)
    }
}

private extension AudioWaveformView {
    enum Style: Equatable {
        case playback
        case recorded
        case live
    }

    struct WaveformSample {
        let average: Double
        let peak: Double

        static let quiet = WaveformSample(average: 0.12, peak: 0.12)
    }
}
