import SwiftUI
import UniformTypeIdentifiers

struct MemoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: MemoryEditSessionViewModel
    @State private var recordingViewModel: VoiceRecordingViewModel
    @State private var isChoosingAudio = false
    @State private var isImportingAudio = false
    @State private var audioImportTask: Task<Void, Never>?
    @State private var isConfirmingPhotoRemoval = false
    @State private var isConfirmingSoundRemoval = false
    @State private var isCompletingSave = false
    @State private var isChoosingJournals = false

    let onSaved: () async -> Void

    init(
        session: MemoryEditSessionViewModel,
        recordingViewModel: VoiceRecordingViewModel,
        onSaved: @escaping () async -> Void
    ) {
        _session = State(wrappedValue: session)
        _recordingViewModel = State(wrappedValue: recordingViewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        @Bindable var session = session

        NavigationStack {
            Form {
                photoSection
                soundSection

                Section("Details") {
                    TextField("Title", text: $session.title)
                    TextField("Description", text: $session.caption, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Memory Date") {
                    DatePicker("Date", selection: $session.capturedAt, displayedComponents: .date)
                }

                if session.supportsJournalEditing {
                    journalSection
                }

                if session.hasPhoto == false && session.hasAudio == false {
                    Section {
                        Label(
                            "A memory must keep at least one photo or sound.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancelEditing() }
                        .disabled(isCompletingSave)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(
                            session.canSave == false
                                || recordingViewModel.hasUnsavedRecording
                                || isCompletingSave
                        )
                }
            }
        }
        .interactiveDismissDisabled(
            session.hasStagedMedia || recordingViewModel.hasUnsavedRecording || isImportingAudio
                || isCompletingSave
        )
        .fileImporter(
            isPresented: $isChoosingAudio,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false,
            onCompletion: importAudio
        )
        .sheet(isPresented: $isChoosingJournals) {
            JournalAssignmentSheet(
                journals: session.availableJournals,
                selectedJournalIDs: session.selectedJournalIDs,
                applySelection: { journalIDs in
                    session.updateJournalSelection(journalIDs)
                    return true
                }
            )
        }
        .task { await session.loadJournals() }
        .alert("Couldn’t Update Memory", isPresented: sessionErrorIsPresented) {
            Button("OK") { session.dismissError() }
        } message: {
            Text(session.errorMessage ?? "Please try again.")
        }
        .alert("Couldn’t Record Sound", isPresented: recordingErrorIsPresented) {
            Button("OK") { recordingViewModel.acknowledgeFailure() }
        } message: {
            Text(recordingViewModel.failureMessage ?? "Please try again.")
        }
    }

    private var photoSection: some View {
        Section("Photo") {
            if session.hasPhoto {
                ManagedPhotoImageView(photoURL: session.photoURL, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
            } else {
                Label("No Photo", systemImage: "photo")
                    .foregroundStyle(.secondary)
            }

            PhotoLibraryPicker(
                title: session.hasPhoto ? "Replace Photo" : "Add Photo",
                onPhotoDataSelected: session.replacePhoto,
                onImportFailure: session.reportImportFailure
            )

            if session.hasPhoto {
                Button("Remove Photo", systemImage: "trash", role: .destructive) {
                    isConfirmingPhotoRemoval = true
                }
                .confirmationDialog(
                    "Remove Photo?",
                    isPresented: $isConfirmingPhotoRemoval,
                    titleVisibility: .visible
                ) {
                    Button("Remove Photo", role: .destructive) { session.removePhoto() }
                } message: {
                    Text(
                        "Saving will permanently remove this photo from the memory. "
                            + "This can’t be undone."
                    )
                }
            }
        }
    }

    private var soundSection: some View {
        Section("Sound") {
            if session.hasAudio {
                Label("Sound Attached", systemImage: "waveform")
            } else {
                Label("No Sound", systemImage: "waveform.slash")
                    .foregroundStyle(.secondary)
            }

            if recordingViewModel.isRecording {
                Button(role: .destructive) {
                    Task { await recordingViewModel.stop() }
                } label: {
                    Label(
                        "Stop Recording  \(recordingViewModel.elapsedDescription)",
                        systemImage: "stop.fill"
                    )
                }
            } else if recordingViewModel.hasUnsavedRecording {
                HStack {
                    ProgressView()
                    Text("Preparing Recording")
                }
            } else {
                Button {
                    Task { await recordingViewModel.start() }
                } label: {
                    Label(
                        session.hasAudio ? "Record Replacement Sound" : "Record Sound",
                        systemImage: "mic"
                    )
                }

                if isImportingAudio {
                    HStack {
                        ProgressView()
                        Text("Adding Sound")
                    }
                } else {
                    Button {
                        isChoosingAudio = true
                    } label: {
                        Label(
                            session.hasAudio ? "Choose Replacement Audio" : "Choose Audio File",
                            systemImage: "folder"
                        )
                    }
                }
            }

            if session.hasAudio && recordingViewModel.hasUnsavedRecording == false {
                Button("Remove Sound", systemImage: "trash", role: .destructive) {
                    isConfirmingSoundRemoval = true
                }
                .confirmationDialog(
                    "Remove Sound?",
                    isPresented: $isConfirmingSoundRemoval,
                    titleVisibility: .visible
                ) {
                    Button("Remove Sound", role: .destructive) { session.removeAudio() }
                } message: {
                    Text(
                        "Saving will permanently remove this sound from the memory. "
                            + "This can’t be undone."
                    )
                }
            }
        }
    }

    private var journalSection: some View {
        Section("Journals") {
            switch session.journalState {
            case .unavailable, .idle, .loading:
                HStack {
                    ProgressView()
                    Text("Loading Journals")
                }
            case .loaded:
                Button {
                    isChoosingJournals = true
                } label: {
                    LabeledContent("Assigned To") {
                        Text(session.journalSelectionDescription)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .foregroundStyle(.primary)
            case .failed:
                Button("Try Loading Journals Again", systemImage: "arrow.clockwise") {
                    Task { await session.loadJournals() }
                }
            }
        }
    }

    private var sessionErrorIsPresented: Binding<Bool> {
        Binding(
            get: { session.errorMessage != nil },
            set: { if $0 == false { session.dismissError() } }
        )
    }

    private var recordingErrorIsPresented: Binding<Bool> {
        Binding(
            get: { recordingViewModel.failureMessage != nil },
            set: { if $0 == false { recordingViewModel.acknowledgeFailure() } }
        )
    }

    private func importAudio(_ result: Result<[URL], any Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            session.reportImportFailure()
            return
        }

        audioImportTask?.cancel()
        isImportingAudio = true
        audioImportTask = Task {
            defer { isImportingAudio = false }
            let fileExtension = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
            let accessedSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if accessedSecurityScope { url.stopAccessingSecurityScopedResource() }
            }

            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    try Data(contentsOf: url, options: .mappedIfSafe)
                }.value
                try Task.checkCancellation()
                session.replaceAudio(data, fileExtension: fileExtension)
            } catch is CancellationError {
                return
            } catch {
                session.reportImportFailure()
            }
        }
    }

    private func saveChanges() {
        guard isCompletingSave == false else { return }
        isCompletingSave = true
        guard session.save() else {
            isCompletingSave = false
            return
        }
        Task {
            await recordingViewModel.shutdown()
            await onSaved()
            dismiss()
        }
    }

    private func cancelEditing() {
        audioImportTask?.cancel()
        Task {
            await recordingViewModel.discardRecording()
            if session.cancel() {
                dismiss()
            }
        }
    }
}
