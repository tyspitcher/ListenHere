// Composes media, optional metadata, and the pinned save action on one stable capture surface.

import SwiftUI

struct CaptureComposerContentView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var mediaWidthIsNarrow = false
    @State private var photoIsLandscape = false

    @Binding var title: String
    @Binding var description: String

    let captureViewModel: CaptureViewModel
    let recordingViewModel: VoiceRecordingViewModel
    let previewViewModel: CaptureMediaPreviewViewModel
    let takePhoto: () -> Void
    let importPhoto: (Data, String) -> Void
    let reportPhotoImportFailure: () -> Void
    let startRecording: () -> Void
    let chooseAudioFile: () -> Void
    let removePhoto: () -> Void
    let removeAudio: () -> Void
    let save: () -> Void

    var body: some View {
        let photoURL = captureViewModel.managedPhotoURL
        let mediaLayout: AnyLayout = dynamicTypeSize.isAccessibilitySize || mediaWidthIsNarrow || photoIsLandscape
            ? AnyLayout(VStackLayout(spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                mediaLayout {
                    CapturePhotoTile(
                        photoURL: photoURL,
                        hasPhoto: captureViewModel.draft.normalizedPhotoFilename != nil,
                        isEnabled: editorIsEnabled,
                        takePhoto: takePhoto,
                        importPhoto: importPhoto,
                        reportImportFailure: reportPhotoImportFailure,
                        removePhoto: removePhoto
                    )

                    CaptureSoundTile(
                        hasAudio: captureViewModel.draft.normalizedAudioFilename != nil,
                        isEnabled: editorIsEnabled,
                        recordingViewModel: recordingViewModel,
                        previewViewModel: previewViewModel,
                        startRecording: startRecording,
                        chooseAudioFile: chooseAudioFile,
                        removeAudio: removeAudio
                    )
                }

                CaptureMetadataFields(
                    title: $title,
                    description: $description,
                    isEnabled: editorIsEnabled
                )
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width < 360
        } action: { isNarrow in
            mediaWidthIsNarrow = isNarrow
        }
        .task(id: photoURL) {
            photoIsLandscape = await ManagedPhotoAspectRatio.isLandscape(photoURL)
        }
        .safeAreaInset(edge: .bottom) {
            CaptureSaveBar(
                canSave: captureViewModel.canSave && recordingViewModel.hasUnsavedRecording == false,
                isSaving: isSaving,
                save: save
            )
        }
    }

    private var editorIsEnabled: Bool {
        guard recordingViewModel.hasUnsavedRecording == false else { return false }
        return if case .editing = captureViewModel.state { true } else { false }
    }

    private var isSaving: Bool {
        if case .saving = captureViewModel.state { true } else { false }
    }

}
