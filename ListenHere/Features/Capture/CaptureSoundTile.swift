// Adds, records, previews, plays, and removes the capture draft's single sound.

import SwiftUI

struct CaptureSoundTile: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let hasAudio: Bool
    let isEnabled: Bool
    let recordingViewModel: VoiceRecordingViewModel
    let previewViewModel: AudioPreviewViewModel
    let startRecording: () -> Void
    let chooseAudioFile: () -> Void
    let removeAudio: () -> Void

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
            soundSourceButtons
        case .requestingPermission:
            ProgressView("Requesting Access")
                .frame(maxWidth: .infinity, minHeight: 180)
        case .preparingRecording:
            ProgressView("Preparing Recording")
                .frame(maxWidth: .infinity, minHeight: 180)
        case .finalizing:
            ProgressView("Adding Sound")
                .frame(maxWidth: .infinity, minHeight: 180)
        case .recording:
            stopRecordingButton
        }
    }

    private var soundSourceButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sound", systemImage: "waveform")
                .font(.headline)
                .foregroundStyle(palette.primaryText)
                .accessibilityAddTraits(.isHeader)

            CaptureSourceButton(
                title: "Record Sound",
                systemImage: "mic",
                accessibilityIdentifier: "capture.recordSound",
                action: startRecording
            )

            CaptureSourceButton(
                title: "Choose Audio File",
                systemImage: "folder",
                accessibilityIdentifier: "capture.chooseAudioFile",
                action: chooseAudioFile
            )
        }
        .padding()
        .tint(palette.secondaryAccent)
        .disabled(isEnabled == false)
        .accessibilityElement(children: .contain)
    }

    private var stopRecordingButton: some View {
        Button {
            Task { await recordingViewModel.stop() }
        } label: {
            HStack(spacing: 10) {
                AudioWaveformView(
                    liveSamples: recordingViewModel.levels,
                    tint: .white
                )
                .frame(maxWidth: .infinity)
                .frame(height: 32)

                Text(recordingViewModel.elapsedDescription)
                    .font(.subheadline.monospacedDigit())

                Label("Stop Recording", systemImage: "stop.fill")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
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
        AudioWaveformPlayerView(
            samples: previewViewModel.waveformSamples,
            playbackState: previewViewModel.audioPlaybackState,
            togglePlayback: previewViewModel.togglePlayback,
            seek: previewViewModel.seek,
            removeAudio: presentRemovalConfirmation
        )
        .padding()
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

    private func presentRemovalConfirmation() {
        removalConfirmationIsPresented = true
    }

}
