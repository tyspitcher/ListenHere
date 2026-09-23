// Groups composer-scoped recording presentation state with its shared still-camera adapter.

import Foundation

@MainActor
struct CaptureRecordingSession {
    let viewModel: VoiceRecordingViewModel
    let photoCameraController: RecordingPhotoCameraController?
}
