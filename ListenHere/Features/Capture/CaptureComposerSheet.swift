// Presents the complete create-memory composer and owns its transient system presentations.

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct CaptureComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    let viewModel: CaptureViewModel
    private let onSaved: () -> Void

    @State private var recordingViewModel: VoiceRecordingViewModel
    @State private var previewViewModel: CaptureMediaPreviewViewModel
    @State private var cameraViewModel: CameraCaptureViewModel
    @State private var title: String
    @State private var description: String
    @State private var currentAlert: CaptureComposerAlert?
    @State private var audioFileImporterIsPresented = false
    @State private var cameraIsPresented = false
    @State private var discardConfirmationIsPresented = false
    @State private var cleanupFailureDiscardConfirmationIsPresented = false
    @State private var cleanupRetryTarget: CleanupRetryTarget?

    init(
        viewModel: CaptureViewModel,
        makeVoiceRecordingViewModel: @escaping (CaptureViewModel) -> VoiceRecordingViewModel,
        makeCaptureMediaPreviewViewModel: @escaping (CaptureViewModel) -> CaptureMediaPreviewViewModel,
        makeCameraCaptureViewModel: @escaping () -> CameraCaptureViewModel,
        onSaved: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onSaved = onSaved
        _recordingViewModel = State(wrappedValue: makeVoiceRecordingViewModel(viewModel))
        _previewViewModel = State(wrappedValue: makeCaptureMediaPreviewViewModel(viewModel))
        _cameraViewModel = State(wrappedValue: makeCameraCaptureViewModel())
        _title = State(initialValue: viewModel.draft.title ?? "")
        _description = State(initialValue: viewModel.draft.caption ?? "")
    }

    var body: some View {
        NavigationStack {
            CaptureComposerContentView(
                title: $title,
                description: $description,
                captureViewModel: viewModel,
                recordingViewModel: recordingViewModel,
                previewViewModel: previewViewModel,
                takePhoto: prepareCamera,
                importPhoto: viewModel.importPhoto,
                reportPhotoImportFailure: viewModel.reportPhotoLibraryImportFailure,
                startRecording: startRecording,
                chooseAudioFile: presentAudioFileImporter,
                removePhoto: removePhoto,
                removeAudio: removeAudio,
                save: save
            )
            .navigationTitle("New Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: requestCancel)
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(viewModel.hasUnsavedDraft || recordingViewModel.hasUnsavedRecording)
        .fileImporter(
            isPresented: $audioFileImporterIsPresented,
            allowedContentTypes: [.audio]
        ) { result in
            importAudioFile(result)
        }
        .fullScreenCover(isPresented: $cameraIsPresented) {
            SystemCameraPicker(
                onPhotoCaptured: importCapturedPhoto,
                onCancel: dismissCamera,
                onFailure: reportCameraImportFailure
            )
            .ignoresSafeArea()
        }
        .task(id: viewModel.draft.audioFilename) {
            await previewViewModel.loadAudio()
        }
        .onChange(of: title) { _, value in
            viewModel.updateTitle(value)
        }
        .onChange(of: description) { _, value in
            viewModel.updateCaption(value)
        }
        .onChange(of: viewModel.state) { _, state in
            captureStateDidChange(state)
        }
        .onChange(of: cameraViewModel.failure) { _, failure in
            if let failure { currentAlert = .camera(failure) }
        }
        .onChange(of: recordingViewModel.state) { _, state in
            if case .failed(let failure) = state { currentAlert = .recording(failure) }
        }
        .onChange(of: recordingViewModel.notice) { _, notice in
            if let notice { currentAlert = .recordingNotice(notice) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                Task { await recordingViewModel.stopForLifecycleEvent() }
            }
        }
        .confirmationDialog(
            "Discard This Memory?",
            isPresented: $discardConfirmationIsPresented,
            titleVisibility: .visible
        ) {
            Button("Discard Memory", role: .destructive, action: discardAndDismiss)
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your unsaved photo, sound, title, and description will be removed.")
        }
        .confirmationDialog(
            "Leave Without Removing Media?",
            isPresented: $cleanupFailureDiscardConfirmationIsPresented,
            titleVisibility: .visible
        ) {
            Button("Leave Anyway", role: .destructive, action: abandonAndDismiss)
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your draft will be discarded. The temporary photo or sound couldn’t be removed and might remain in private app storage.")
        }
        .alert(
            currentAlert?.title ?? "Couldn’t Update Memory",
            isPresented: alertIsPresented,
            presenting: currentAlert,
            actions: alertActions,
            message: { alert in Text(alert.message) }
        )
        .onDisappear(perform: shutdown)
    }

    private var alertIsPresented: Binding<Bool> {
        Binding(
            get: { currentAlert != nil },
            set: { isPresented in
                if isPresented == false { acknowledgeCurrentAlert() }
            }
        )
    }

    @ViewBuilder
    private func alertActions(for alert: CaptureComposerAlert) -> some View {
        switch alert {
        case .capture(.mediaRemoval), .capture(.cleanupAfterSaveFailure):
            Button("Try Again", action: retryCleanup)
            Button("Keep Editing", action: acknowledgeCurrentAlert)
            Button("Discard Draft…", role: .destructive, action: requestAbandonAfterCleanupFailure)
        case .camera(let failure) where failure.canOpenSettings:
            Button("Open Settings", action: openSettings)
            Button("Not Now", role: .cancel, action: acknowledgeCurrentAlert)
        case .recording(.permissionDenied):
            Button("Open Settings", action: openSettings)
            Button("Keep Editing", role: .cancel, action: acknowledgeCurrentAlert)
        case .capture, .camera, .recording, .recordingNotice, .cameraImport:
            Button("OK", action: acknowledgeCurrentAlert)
        }
    }

    private func prepareCamera() {
        Task {
            await previewViewModel.stopPlayback()
            if await cameraViewModel.prepareCamera() {
                cameraIsPresented = true
            }
        }
    }

    private func importCapturedPhoto(_ photo: CapturedPhoto) {
        cameraIsPresented = false
        viewModel.importPhoto(photo.data, preferredFileExtension: photo.preferredFileExtension)
    }

    private func dismissCamera() {
        cameraIsPresented = false
    }

    private func reportCameraImportFailure() {
        cameraIsPresented = false
        currentAlert = .cameraImport
    }

    private func startRecording() {
        Task {
            await previewViewModel.stopPlayback()
            await recordingViewModel.start()
        }
    }

    private func presentAudioFileImporter() {
        Task {
            await previewViewModel.stopPlayback()
            audioFileImporterIsPresented = true
        }
    }

    private func importAudioFile(_ result: Result<URL, Error>) {
        let url: URL
        do {
            url = try result.get()
        } catch let error as CocoaError where error.code == .userCancelled {
            return
        } catch {
            viewModel.reportAudioImportFailure()
            return
        }

        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }

        do {
            // FileImporter grants temporary access outside the sandbox. Copy bytes while that
            // access is valid and persist only ListenHere's private managed filename.
            let data = try Data(contentsOf: url)
            viewModel.importAudio(
                data,
                preferredFileExtension: url.pathExtension.isEmpty ? "m4a" : url.pathExtension
            )
        } catch {
            viewModel.reportAudioImportFailure()
        }
    }

    private func removePhoto() {
        cleanupRetryTarget = .photo
        viewModel.removePhoto()
        if viewModel.draft.normalizedPhotoFilename == nil { cleanupRetryTarget = nil }
    }

    private func removeAudio() {
        Task {
            cleanupRetryTarget = .audio
            await previewViewModel.resetAudio()
            viewModel.removeAudio()
            if viewModel.draft.normalizedAudioFilename != nil {
                await previewViewModel.loadAudio()
            } else {
                cleanupRetryTarget = nil
            }
        }
    }

    private func save() {
        Task {
            await previewViewModel.stopPlayback()
            viewModel.save()
        }
    }

    private func requestCancel() {
        Task {
            if recordingViewModel.isRecording {
                await recordingViewModel.stop()
            }

            if viewModel.hasUnsavedDraft || recordingViewModel.hasUnsavedRecording {
                discardConfirmationIsPresented = true
            } else {
                await performDiscardAndDismiss()
            }
        }
    }

    private func discardAndDismiss() {
        Task { await performDiscardAndDismiss() }
    }

    private func performDiscardAndDismiss() async {
        await previewViewModel.shutdown()
        await recordingViewModel.discardRecording()
        cleanupRetryTarget = .draft
        if viewModel.discardDraft() { dismiss() }
    }

    private func retryCleanup() {
        let retryTarget = cleanupRetryTarget ?? .draft
        currentAlert = nil
        viewModel.acknowledgeFailure()

        switch retryTarget {
        case .photo:
            removePhoto()
        case .audio:
            removeAudio()
        case .draft:
            discardAndDismiss()
        }
    }

    private func abandonAndDismiss() {
        Task {
            await previewViewModel.shutdown()
            await recordingViewModel.discardRecording()
            viewModel.abandonDraftAfterCleanupFailure()
            dismiss()
        }
    }

    private func requestAbandonAfterCleanupFailure() {
        acknowledgeCurrentAlert()
        cleanupFailureDiscardConfirmationIsPresented = true
    }

    private func captureStateDidChange(_ state: CaptureState) {
        switch state {
        case .failed(let failure):
            if failure == .cleanupAfterSaveFailure { cleanupRetryTarget = .draft }
            currentAlert = .capture(failure)
        case .saved:
            onSaved()
        case .editing, .saving:
            break
        }
    }

    private func acknowledgeCurrentAlert() {
        defer { currentAlert = nil }
        switch currentAlert {
        case .capture:
            viewModel.acknowledgeFailure()
        case .camera:
            cameraViewModel.acknowledgeFailure()
        case .recording:
            recordingViewModel.acknowledgeFailure()
        case .recordingNotice:
            recordingViewModel.acknowledgeNotice()
        case .cameraImport, .none:
            break
        }
    }

    private func openSettings() {
        acknowledgeCurrentAlert()
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }

    private func shutdown() {
        Task {
            await previewViewModel.shutdown()
            await recordingViewModel.shutdown()
        }
    }
}

private extension CaptureComposerSheet {
    enum CleanupRetryTarget {
        case photo
        case audio
        case draft
    }
}
