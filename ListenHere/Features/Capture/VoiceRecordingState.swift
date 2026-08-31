// Models the mutually exclusive states of the in-composer ambient recording control.

import Foundation

enum VoiceRecordingState: Equatable {
    case idle
    case requestingPermission
    case recording(elapsed: TimeInterval, levels: [Double])
    case finalizing
    case failed(VoiceRecordingFailure)
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
