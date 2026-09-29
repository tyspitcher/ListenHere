// Prepares the exact media a person chooses before opening the system share sheet.

import Foundation
import Observation

enum MemoryShareOption: CaseIterable, Identifiable {
    case video
    case photo
    case audio

    var id: Self { self }

    var title: String {
        switch self {
        case .video: "Share Video"
        case .photo: "Share Photo"
        case .audio: "Share Audio"
        }
    }

    var detail: String {
        switch self {
        case .video: "Photo and ambient sound"
        case .photo: "Photo only"
        case .audio: "Ambient sound only"
        }
    }

    var systemImage: String {
        switch self {
        case .video: "film"
        case .photo: "photo"
        case .audio: "waveform"
        }
    }
}

struct PreparedMemoryShare: Identifiable {
    let id = UUID()
    let url: URL
    let isTemporaryExport: Bool
}

@MainActor
@Observable
final class MemoryShareViewModel: Identifiable {
    enum State: Equatable {
        case ready
        case preparing(MemoryShareOption, progress: Double)
        case failed
    }

    let id = UUID()
    private(set) var state: State = .ready
    private(set) var preparedShare: PreparedMemoryShare?

    let availability: MemorySharingAvailability
    private let photoURL: URL?
    private let audioURL: URL?
    private let videoExporter: any MemoryVideoExporting

    init(
        availability: MemorySharingAvailability,
        photoURL: URL?,
        audioURL: URL?,
        videoExporter: any MemoryVideoExporting
    ) {
        self.availability = availability
        self.photoURL = photoURL
        self.audioURL = audioURL
        self.videoExporter = videoExporter
    }

    var options: [MemoryShareOption] {
        switch availability {
        case .photo:
            [.photo]
        case .audio:
            [.audio]
        case .photoAndAudio:
            [.video, .photo, .audio]
        case .unavailable:
            []
        }
    }

    var preparationProgress: Double? {
        guard case .preparing(_, let progress) = state else { return nil }
        return progress
    }

    func prepareShare(_ option: MemoryShareOption) async {
        guard options.contains(option) else { return }
        state = .preparing(option, progress: option == .video ? 0 : 1)

        do {
            let share: PreparedMemoryShare
            switch option {
            case .photo:
                guard let photoURL else { throw ShareError.missingMedia }
                share = PreparedMemoryShare(url: photoURL, isTemporaryExport: false)
            case .audio:
                guard let audioURL else { throw ShareError.missingMedia }
                share = PreparedMemoryShare(url: audioURL, isTemporaryExport: false)
            case .video:
                guard let photoURL, let audioURL else { throw ShareError.missingMedia }
                let outputURL = try await videoExporter.exportVideo(
                    photoURL: photoURL,
                    audioURL: audioURL,
                    progress: { [weak self] progress in
                        guard case .preparing(.video, _) = self?.state else { return }
                        self?.state = .preparing(.video, progress: progress)
                    }
                )
                share = PreparedMemoryShare(url: outputURL, isTemporaryExport: true)
            }
            guard Task.isCancelled == false else {
                if share.isTemporaryExport {
                    videoExporter.discardTemporaryExport(at: share.url)
                }
                state = .ready
                return
            }
            preparedShare = share
            state = .ready
        } catch is CancellationError {
            state = .ready
        } catch {
            state = .failed
        }
    }

    func finishSharing(_ share: PreparedMemoryShare) {
        if share.isTemporaryExport {
            videoExporter.discardTemporaryExport(at: share.url)
        }
        preparedShare = nil
    }

    func dismissFailure() {
        state = .ready
    }

    private enum ShareError: Error {
        case missingMedia
    }
}
