// Presents a familiar still-camera experience without interrupting ambient audio recording.

import AVFoundation
import SwiftUI
import UIKit

struct RecordingPhotoCamera: View {
    private enum CameraLayout {
        static let zoomControlDiameter: CGFloat = 44
        static let zoomRowClearance: CGFloat = zoomControlDiameter + 8
        static let liveControlPanelHeight: CGFloat = 190
    }

    let recordingViewModel: VoiceRecordingViewModel
    let onPhotoCaptured: (CapturedPhoto) -> Void
    let onCancel: () -> Void
    let onFailure: () -> Void

    @State private var camera: RecordingPhotoCameraController
    @State private var capabilities = RecordingPhotoCameraCapabilities.unavailable
    @State private var capturedPhoto: CapturedPhoto?
    @State private var isCameraReady = false
    @State private var isCapturing = false
    @State private var keepsCameraConfiguredAfterDismissal = false
    @State private var zoomFactor = 1.0
    @State private var flashMode = RecordingCameraFlashMode.auto

    init(
        camera: RecordingPhotoCameraController,
        recordingViewModel: VoiceRecordingViewModel,
        onPhotoCaptured: @escaping (CapturedPhoto) -> Void,
        onCancel: @escaping () -> Void,
        onFailure: @escaping () -> Void
    ) {
        _camera = State(initialValue: camera)
        self.recordingViewModel = recordingViewModel
        self.onPhotoCaptured = onPhotoCaptured
        self.onCancel = onCancel
        self.onFailure = onFailure
    }

    var body: some View {
        ZStack {
            cameraSurface
        }
        .background(.black)
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if capturedPhoto == nil {
                liveCameraControls
            } else {
                reviewControls
            }
        }
        .task {
            camera.start(
                onReady: cameraDidBecomeReady,
                onFailure: onFailure
            )
        }
        .onDisappear {
            // Accepting a photo dismisses this full-screen view. Releasing the camera graph at
            // that exact point can interrupt microphone sample delivery, so keep the shared
            // session configured until the ambient recording itself ends. Cancel still releases
            // the camera promptly.
            if keepsCameraConfiguredAfterDismissal == false {
                camera.stop()
            }
        }
    }

    @ViewBuilder
    private var cameraSurface: some View {
        if let capturedPhoto,
           let image = UIImage(data: capturedPhoto.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                .ignoresSafeArea()
                .accessibilityLabel("Photo preview")
        } else {
            RecordingPhotoCameraPreview(
                camera: camera,
                onZoomChanged: { zoomFactor = $0 }
            )
            .ignoresSafeArea()
            .accessibilityLabel("Camera preview")
            .accessibilityHint("Tap to focus or pinch to zoom.")
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .frame(width: 100, height: 44, alignment: .leading)

            recordingStatus
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

            if capturedPhoto == nil, capabilities.supportsFlash {
                Menu("Flash, \(flashMode.title)", systemImage: flashMode.systemImage) {
                    Picker("Flash", selection: $flashMode) {
                        ForEach(capabilities.flashModes) { mode in
                            Label(mode.title, systemImage: mode.systemImage)
                                .tag(mode)
                        }
                    }
                }
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                .tint(.white)
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.black)
    }

    private var recordingStatus: some View {
        Label(
            "Recording \(recordingViewModel.elapsedDescription)",
            systemImage: "record.circle.fill"
        )
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.55), in: .capsule)
        .accessibilityLabel(
            "Ambient sound recording continues, \(recordingViewModel.elapsedDescription)"
        )
    }

    private var liveCameraControls: some View {
        ZStack(alignment: .top) {
            Color.black

            if capabilities.zoomOptions.count > 1 {
                zoomControls
                    // The system-camera-style zoom row belongs in the live preview, not on the
                    // black shutter panel. Keep one control diameter plus breathing room clear.
                    .offset(y: -CameraLayout.zoomRowClearance)
            }

            Button(action: capturePhoto) {
                Circle()
                    .fill(.white)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Circle()
                            .stroke(.black.opacity(0.35), lineWidth: 3)
                            .padding(5)
                    }
                    .overlay {
                        if isCapturing {
                            ProgressView()
                                .tint(.black)
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(isCameraReady == false || isCapturing)
            .padding(.top, 54)
            .accessibilityLabel("Take Photo While Recording")
            .accessibilityHint("Captures a photo and keeps ambient sound recording.")
        }
        .foregroundStyle(.white)
        .frame(height: CameraLayout.liveControlPanelHeight)
        .background(.black)
    }

    private var zoomControls: some View {
        HStack(spacing: 12) {
            ForEach(capabilities.zoomOptions) { option in
                Button(option.label) {
                    selectZoom(option)
                }
                .font(.subheadline.monospacedDigit().bold())
                .foregroundStyle(isSelected(option) ? .yellow : .white)
                .frame(
                    width: CameraLayout.zoomControlDiameter,
                    height: CameraLayout.zoomControlDiameter
                )
                .background(.black.opacity(0.55), in: .circle)
                .accessibilityLabel("Zoom \(option.label)")
                .accessibilityAddTraits(isSelected(option) ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Camera zoom")
    }

    private var reviewControls: some View {
        HStack(spacing: 16) {
            Button("Retake", action: retakePhoto)
            .buttonStyle(.bordered)
            .tint(.white)
            .frame(maxWidth: .infinity, minHeight: 44)

            Button("Use Photo", action: usePhoto)
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(.black)
        .accessibilityElement(children: .contain)
    }

    private func cameraDidBecomeReady(_ capabilities: RecordingPhotoCameraCapabilities) {
        self.capabilities = capabilities
        flashMode = capabilities.flashModes.contains(.auto) ? .auto : .off
        zoomFactor = capabilities.initialZoomFactor
        isCameraReady = true
        Task { await recordingViewModel.cameraSessionDidStart() }
    }

    private func capturePhoto() {
        isCapturing = true
        camera.capturePhoto(flashMode: flashMode) { result in
            isCapturing = false
            switch result {
            case .success(let photo):
                capturedPhoto = photo
            case .failure:
                onFailure()
            }
        }
    }

    private func selectZoom(_ option: RecordingCameraZoomOption) {
        zoomFactor = option.captureFactor
        camera.setZoomFactor(option.captureFactor)
    }

    private func isSelected(_ option: RecordingCameraZoomOption) -> Bool {
        abs(zoomFactor - option.captureFactor) < 0.05
    }

    private func retakePhoto() {
        capturedPhoto = nil
    }

    private func usePhoto() {
        guard let capturedPhoto else { return }
        keepsCameraConfiguredAfterDismissal = true
        onPhotoCaptured(capturedPhoto)
    }
}
