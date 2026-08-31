#if DEBUG
import Foundation
import SwiftUI
import UIKit

@MainActor
private struct CaptureComposerPreview: View {
    enum Mode {
        case empty
        case photo
        case sound
        case both
        case recording
        case saving
        case permissionDenied
        case cleanupFailed
    }

    @State private var captureViewModel: CaptureViewModel
    @State private var recordingViewModel: VoiceRecordingViewModel
    @State private var previewViewModel: CaptureMediaPreviewViewModel
    @State private var title: String
    @State private var description: String

    init(_ mode: Mode) {
        let models = Self.makeModels(for: mode)
        _captureViewModel = State(initialValue: models.capture)
        _recordingViewModel = State(initialValue: models.recording)
        _previewViewModel = State(initialValue: models.preview)
        _title = State(initialValue: models.capture.draft.title ?? "")
        _description = State(initialValue: models.capture.draft.caption ?? "")
    }

    var body: some View {
        NavigationStack {
            CaptureComposerContentView(
                title: $title,
                description: $description,
                captureViewModel: captureViewModel,
                recordingViewModel: recordingViewModel,
                previewViewModel: previewViewModel,
                takePhoto: {},
                importPhoto: { _, _ in },
                reportPhotoImportFailure: {},
                startRecording: {},
                chooseAudioFile: {},
                removePhoto: {},
                removeAudio: {},
                save: {}
            )
            .navigationTitle("New Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {}
                }
            }
        }
        .appTheme(.listenHere)
    }

    private static func makeModels(
        for mode: Mode
    ) -> (
        capture: CaptureViewModel,
        recording: VoiceRecordingViewModel,
        preview: CaptureMediaPreviewViewModel
    ) {
        let mediaStore = MediaStore()
        let capture = CaptureViewModel(
            origin: .allMemories,
            memoryRepository: PreviewMemoryRepository(),
            mediaStore: mediaStore
        )
        let recording = VoiceRecordingViewModel(
            service: PreviewAudioRecordingService(),
            clock: ContinuousRecordingClock()
        )
        let preview = CaptureMediaPreviewViewModel(
            captureViewModel: capture,
            audioPlaybackService: PlaybackService(),
            waveformAnalyzer: PreviewAudioWaveformAnalyzer()
        )

        let photoData = UIImage(named: "BeachMemory")?.pngData() ?? Data("photo".utf8)
        let waveform = (0..<48).map { index in
            0.18 + (sin(Double(index) * 0.7) + 1) * 0.32
        }

        switch mode {
        case .empty:
            break
        case .photo:
            capture.importPhoto(photoData, preferredFileExtension: "png")
        case .sound:
            addPreviewAudio(to: capture)
            preview.setPreviewState(playbackState: .ready(duration: 18), samples: waveform)
        case .both:
            capture.importPhoto(photoData, preferredFileExtension: "png")
            addPreviewAudio(to: capture)
            capture.updateTitle("Harbor at Low Tide")
            capture.updateCaption("Water folding softly against the dock.")
            preview.setPreviewState(playbackState: .paused(elapsed: 6, duration: 18), samples: waveform)
        case .recording:
            recording.setPreviewState(.recording(elapsed: 14, levels: waveform))
        case .saving:
            capture.importPhoto(photoData, preferredFileExtension: "png")
            capture.setPreviewState(.saving)
        case .permissionDenied:
            recording.setPreviewState(.failed(.permissionDenied))
        case .cleanupFailed:
            capture.importPhoto(photoData, preferredFileExtension: "png")
            capture.setPreviewState(.failed(.mediaRemoval))
        }

        return (capture, recording, preview)
    }

    private static func addPreviewAudio(to capture: CaptureViewModel) {
        capture.importAudio(
            Data("synthetic preview audio".utf8),
            preferredFileExtension: "m4a",
            durationSeconds: 18
        )
    }
}

private extension CaptureComposerPreview {
    @MainActor
    final class MediaStore: ManagedMediaDeleting, ManagedMediaReading, ManagedMediaStoring {
        private let root = FileManager.default.temporaryDirectory
            .appending(path: "ListenHereComposerPreview-\(UUID().uuidString)")
        private var sequence = 0

        func store(
            _ data: Data,
            as kind: ManagedMediaKind,
            preferredFileExtension: String
        ) throws -> ManagedMediaFile {
            sequence += 1
            let filename = "\(kind.directoryName)/preview-\(sequence).\(preferredFileExtension)"
            let url = root.appending(path: filename)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            return ManagedMediaFile(filename: filename, kind: kind)
        }

        func deleteManagedFiles(named filenames: Set<String>) throws {
            for filename in filenames {
                try? FileManager.default.removeItem(at: root.appending(path: filename))
            }
        }

        func fileURL(for filename: String) throws -> URL {
            root.appending(path: filename)
        }
    }

    @MainActor
    final class PlaybackService: AudioPlaybackServicing {
        var currentTime: TimeInterval = 0
        let duration: TimeInterval = 18
        var isPlaying = false

        func loadAudio(at url: URL) async throws { currentTime = 0 }
        func play() throws { isPlaying = true }
        func pause() { isPlaying = false }
        func stop() async {
            currentTime = 0
            isPlaying = false
        }
    }
}

#Preview("Composer — Empty") {
    CaptureComposerPreview(.empty)
}

#Preview("Composer — Photo") {
    CaptureComposerPreview(.photo)
}

#Preview("Composer — Sound") {
    CaptureComposerPreview(.sound)
}

#Preview("Composer — Both Media") {
    CaptureComposerPreview(.both)
}

#Preview("Composer — Recording") {
    CaptureComposerPreview(.recording)
}

#Preview("Composer — Saving") {
    CaptureComposerPreview(.saving)
}

#Preview("Composer — Permission Denied") {
    CaptureComposerPreview(.permissionDenied)
}

#Preview("Composer — Cleanup Failed") {
    CaptureComposerPreview(.cleanupFailed)
}
#endif
