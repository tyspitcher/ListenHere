// Identifies the single active alert presented by the capture composer.

enum CaptureComposerAlert: Identifiable, Equatable {
    case capture(CaptureFailure)
    case camera(CameraCaptureFailure)
    case recording(VoiceRecordingFailure)
    case recordingNotice(String)
    case cameraImport

    var id: String {
        switch self {
        case .capture(let failure):
            "capture-\(String(describing: failure))"
        case .camera(let failure):
            "camera-\(String(describing: failure))"
        case .recording(let failure):
            "recording-\(String(describing: failure))"
        case .recordingNotice:
            "recording-notice"
        case .cameraImport:
            "camera-import"
        }
    }

    var title: String {
        switch self {
        case .capture(.mediaRemoval), .capture(.cleanupAfterSaveFailure):
            "Couldn’t Remove Media"
        case .capture:
            "Couldn’t Update Memory"
        case .camera:
            "Camera Unavailable"
        case .recording(.permissionDenied):
            "Microphone Access Needed"
        case .recording:
            "Couldn’t Record Sound"
        case .recordingNotice:
            "Recording Stopped"
        case .cameraImport:
            "Couldn’t Add Photo"
        }
    }

    var message: String {
        switch self {
        case .capture(let failure):
            failure.recoveryMessage
        case .camera(let failure):
            failure.message
        case .recording(let failure):
            failure.message
        case .recordingNotice(let message):
            message
        case .cameraImport:
            "The captured photo couldn’t be added. Please try again."
        }
    }
}
