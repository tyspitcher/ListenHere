import Testing

@testable import ListenHere

struct VoiceRecordingStateTests {
    @Test("Only an active recording permits taking a live photo")
    func permitsLivePhotoCaptureDuringRecording() {
        #expect(VoiceRecordingState.idle.permitsPhotoCapture)
        #expect(VoiceRecordingState.recording(elapsed: 1, levels: []).permitsPhotoCapture)
        #expect(VoiceRecordingState.requestingPermission.permitsPhotoCapture == false)
        #expect(VoiceRecordingState.preparingRecording.permitsPhotoCapture == false)
        #expect(VoiceRecordingState.finalizing.permitsPhotoCapture == false)
    }

    @Test("System media pickers stay unavailable while a recording is in progress")
    func blocksMediaSourceSelectionDuringRecording() {
        #expect(VoiceRecordingState.idle.permitsMediaSourceSelection)
        #expect(VoiceRecordingState.failed(.couldNotStart).permitsMediaSourceSelection)
        #expect(VoiceRecordingState.recording(elapsed: 1, levels: []).permitsMediaSourceSelection == false)
    }
}
