// Renders an audio position indicator and the corresponding deliberate playback action.

import Foundation
import SwiftUI

struct AudioPlaybackProgressView: View {
    let elapsed: TimeInterval
    let duration: TimeInterval
    let buttonTitle: String
    let buttonImage: String
    let togglePlayback: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView(value: min(elapsed, duration), total: max(duration, 1))
                .accessibilityLabel("Audio progress")
                .accessibilityValue("\(formattedTime(elapsed)) of \(formattedTime(duration))")

            HStack {
                Button(buttonTitle, systemImage: buttonImage, action: togglePlayback)
                    .buttonStyle(.borderedProminent)
                Spacer()
                Text("\(formattedTime(elapsed)) / \(formattedTime(duration))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formattedTime(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
