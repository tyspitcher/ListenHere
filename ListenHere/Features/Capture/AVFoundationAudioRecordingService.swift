// Encapsulates AVFoundation microphone permission, temporary-file recording, and audio-session cleanup.

import AVFoundation
import Foundation
import OSLog

@MainActor
final class AVFoundationAudioRecordingService: NSObject, AudioRecordingServicing {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private let eventContinuation: AsyncStream<AudioRecordingServiceEvent>.Continuation
    private var audioSessionObservation: NotificationCenter.ObservationToken?
    private static let logger = Logger(
        subsystem: "com.tysonpitcher.ListenHere",
        category: "AudioRecording"
    )

    let events: AsyncStream<AudioRecordingServiceEvent>

    override init() {
        let eventStream = AsyncStream<AudioRecordingServiceEvent>.makeStream()
        events = eventStream.stream
        eventContinuation = eventStream.continuation
        super.init()
        // iOS 27 distinguishes an app-requested deactivation from a system interruption.
        // Only a system interruption should stop an active ambient recording; the playback
        // service intentionally deactivates before recording begins.
        audioSessionObservation = NotificationCenter.default.addObserver(
            of: AVAudioSession.self,
            for: .didBecomeInactive
        ) { [weak self] message in
            guard case .systemInterruption = message.deactivationResult else { return }
            self?.eventContinuation.yield(.interruptionBegan)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteDidChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    deinit {
        if let audioSessionObservation {
            NotificationCenter.default.removeObserver(audioSessionObservation)
        }
        NotificationCenter.default.removeObserver(self)
        eventContinuation.finish()
    }

    func requestPermission() async -> Bool {
        // AVAudioSession owns the microphone permission boundary; the system prompt is shown
        // only once and subsequent calls return the user's existing authorization decision.
        Self.logger.debug("Microphone permission requested.")
        return await withCheckedContinuation { continuation in
            // AVAudioApplication is the modern permission API; AVAudioSession still owns
            // the active route and category once recording begins.
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start() async throws {
        let session = AVAudioSession.sharedInstance()
        Self.logger.debug("Audio recording start requested.")
        // AVAudioSession configures the app's audio route and activation. Keeping this in the
        // service isolates interruptions, route changes, and hardware behavior from SwiftUI.
        do {
            try session.setCategory(.record, mode: .default, options: [.allowBluetoothHFP])
            // iOS 27's async activation avoids blocking MainActor while the system negotiates a
            // microphone route, which can take long enough to trigger the device responsiveness checker.
            guard try await session.activate(options: []) else {
                throw RecordingError.activationFailed
            }
        } catch {
            Self.logger.error("Audio recording session activation failed.")
            throw error
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        // AVAudioRecorder writes compressed AAC audio to a temporary URL; CaptureViewModel
        // copies the finished bytes into ListenHere's managed media store after confirmation.
        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            // Metering samples AVAudioRecorder's current power without exposing AVFoundation to
            // the composer. The view model converts these samples into a visible live waveform.
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            guard recorder.record() else { throw RecordingError.startFailed }
            self.recorder = recorder
            recordingURL = url
            Self.logger.debug("Audio recording started.")
        } catch {
            try? FileManager.default.removeItem(at: url)
            _ = try? await session.deactivate(options: [.notifyOthersOnDeactivation])
            Self.logger.error("Audio recorder initialization failed.")
            throw error
        }
    }

    func stop() async throws -> AudioRecording {
        guard let recorder, let url = recordingURL else {
            Self.logger.error("Audio recording finalization was requested without an active recording.")
            throw RecordingError.notRecording
        }
        Self.logger.debug("Audio recording finalization requested.")
        // AVAudioRecorder reports `currentTime` as zero after `stop()`. Capture the elapsed
        // duration first so the recording view model can validate the real clip length.
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        recordingURL = nil
        let recording = Result {
            AudioRecording(data: try Data(contentsOf: url), duration: duration)
        }
        switch recording {
        case .success:
            Self.logger.debug("Temporary audio recording read completed.")
        case .failure:
            Self.logger.error("Temporary audio recording read failed.")
        }
        try? FileManager.default.removeItem(at: url)
        // Stop I/O before asynchronously releasing the route, as required by AVAudioSession.
        _ = try? await AVAudioSession.sharedInstance()
            .deactivate(options: [.notifyOthersOnDeactivation])
        return try recording.get()
    }

    func cancel() async {
        Self.logger.debug("Audio recording cancellation requested.")
        recorder?.stop()
        recorder = nil
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
        _ = try? await AVAudioSession.sharedInstance()
            .deactivate(options: [.notifyOthersOnDeactivation])
    }

    func normalizedMeterLevel() -> Double {
        guard let recorder, recorder.isRecording else { return 0 }
        recorder.updateMeters()
        let decibels = max(-60, min(0, recorder.averagePower(forChannel: 0)))
        return pow(10, Double(decibels) / 20)
    }

    @objc private func audioRouteDidChange(_ notification: Notification) {
        guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason),
              reason == .oldDeviceUnavailable || reason == .noSuitableRouteForCategory else {
            return
        }
        eventContinuation.yield(.routeChanged)
    }

    enum RecordingError: Error {
        case activationFailed
        case startFailed
        case notRecording
    }
}
