// Adds, records, previews, plays, and removes the capture draft's single sound.

import SwiftUI

struct CaptureSoundTile: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let hasAudio: Bool
    let isEnabled: Bool
    let recordingViewModel: VoiceRecordingViewModel
    let previewViewModel: CaptureMediaPreviewViewModel
    let startRecording: () -> Void
    let chooseAudioFile: () -> Void
    let removeAudio: () -> Void

    @State private var sourcePopoverIsPresented = false
    @State private var removalConfirmationIsPresented = false

    var body: some View {
        Group {
            if hasAudio {
                audioPreview
            } else {
                recordingControl
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(palette.surface, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(palette.separator)
        }
    }

    private var palette: AppPalette {
        theme.palette(for: colorScheme)
    }

    @ViewBuilder
    private var recordingControl: some View {
        switch recordingViewModel.state {
        case .idle, .failed:
            addSoundButton
        case .requestingPermission:
            ProgressView("Requesting Access")
                .frame(maxWidth: .infinity, minHeight: 180)
        case .finalizing:
            ProgressView("Adding Sound")
                .frame(maxWidth: .infinity, minHeight: 180)
        case .recording:
            stopRecordingButton
        }
    }

    private var addSoundButton: some View {
        Button(action: presentSources) {
            VStack(spacing: 12) {
                Image(systemName: "waveform.badge.plus")
                    .font(.largeTitle)
                Text("Add Sound")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.secondaryAccent)
        .disabled(isEnabled == false)
        .accessibilityHint("Choose recording or an audio file.")
        .popover(isPresented: $sourcePopoverIsPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Sound")
                    .font(.headline)
                    .padding(.bottom, 4)

                Button("Record Sound", systemImage: "mic.fill", action: chooseRecording)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)

                Button("Choose Audio File", systemImage: "doc.badge.plus", action: chooseFile)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .padding()
            .presentationCompactAdaptation(.sheet)
        }
    }

    private var stopRecordingButton: some View {
        Button {
            Task { await recordingViewModel.stop() }
        } label: {
            VStack(spacing: 10) {
                Label("Stop Recording", systemImage: "stop.fill")
                    .font(.headline)
                Text(recordingViewModel.elapsedDescription)
                    .font(.title3.monospacedDigit())
                AudioWaveformView(
                    samples: recordingViewModel.levels,
                    progress: 1,
                    tint: .white
                )
                .frame(height: 42)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            .padding(.horizontal)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 20))
        .tint(palette.destructive)
        .accessibilityLabel("Stop Recording, \(recordingViewModel.elapsedDescription)")
        .accessibilityInputLabels(["Stop Recording"])
        .accessibilityHint("Stops recording and adds the captured sound to this memory.")
    }

    private var audioPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            AudioWaveformView(
                samples: previewViewModel.waveformSamples,
                progress: previewViewModel.playbackProgress,
                tint: palette.secondaryAccent
            )
            .frame(height: 72)

            HStack(spacing: 8) {
                Button(
                    playbackButtonTitle,
                    systemImage: playbackButtonImage,
                    action: previewViewModel.togglePlayback
                )
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(playbackIsUnavailable)

                Text(playbackTimeDescription)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Remove Sound", systemImage: "trash", action: presentRemovalConfirmation)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(palette.destructive)
                    .frame(minWidth: 44, minHeight: 44)
                    .confirmationDialog(
                        "Remove This Sound?",
                        isPresented: $removalConfirmationIsPresented,
                        titleVisibility: .visible
                    ) {
                        Button("Remove Sound", role: .destructive, action: removeAudio)
                        Button("Keep Sound", role: .cancel) {}
                    } message: {
                        Text("The sound will be removed from this unsaved memory.")
                    }
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
    }

    private var playbackButtonTitle: String {
        if case .playing = previewViewModel.audioPlaybackState { "Pause Sound" } else { "Play Sound" }
    }

    private var playbackButtonImage: String {
        if case .playing = previewViewModel.audioPlaybackState { "pause.fill" } else { "play.fill" }
    }

    private var playbackIsUnavailable: Bool {
        switch previewViewModel.audioPlaybackState {
        case .unavailable, .failed:
            true
        case .ready, .playing, .paused:
            false
        }
    }

    private var playbackTimeDescription: String {
        switch previewViewModel.audioPlaybackState {
        case .ready(let duration):
            "0:00 / \(Self.formattedTime(duration ?? 0))"
        case .playing(let elapsed, let duration), .paused(let elapsed, let duration):
            "\(Self.formattedTime(elapsed)) / \(Self.formattedTime(duration))"
        case .unavailable:
            "Audio unavailable"
        case .failed:
            "Playback failed"
        }
    }

    private func presentSources() {
        sourcePopoverIsPresented = true
    }

    private func chooseRecording() {
        sourcePopoverIsPresented = false
        startRecording()
    }

    private func chooseFile() {
        sourcePopoverIsPresented = false
        chooseAudioFile()
    }

    private func presentRemovalConfirmation() {
        removalConfirmationIsPresented = true
    }

    private static func formattedTime(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return seconds < 10 ? "\(minutes):0\(seconds)" : "\(minutes):\(seconds)"
    }
}
