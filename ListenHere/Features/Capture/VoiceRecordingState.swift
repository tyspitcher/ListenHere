// Models the mutually exclusive states of the in-composer ambient recording control.

import Foundation

enum VoiceRecordingState: Equatable {
    case idle
    case requestingPermission
    case preparingRecording
    case recording(elapsed: TimeInterval, levels: [AudioMeterLevel])
    case finalizing
    case failed(VoiceRecordingFailure)

    /// A live camera capture stays inside ListenHere's process, so it can safely continue an
    /// active ambient recording. System pickers remain unavailable until recording finishes.
    var permitsPhotoCapture: Bool {
        switch self {
        case .idle, .recording, .failed:
            true
        case .requestingPermission, .preparingRecording, .finalizing:
            false
        }
    }

    var permitsMediaSourceSelection: Bool {
        switch self {
        case .idle, .failed:
            true
        case .requestingPermission, .preparingRecording, .recording, .finalizing:
            false
        }
    }
}

enum VoiceRecordingFailure: Equatable {
    case permissionDenied
    case couldNotStart
    case couldNotFinish

    var message: String {
        switch self {
        case .permissionDenied:
            "Microphone access is required to record ambient sound. Enable it in Settings and try again."
        case .couldNotStart:
            "The recording couldn’t start. Please try again."
        case .couldNotFinish:
            "The recording couldn’t be saved. Please try again."
        }
    }
}
