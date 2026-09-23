// Encapsulates AVFoundation microphone permission, capture, and audio-session cleanup.

import AVFoundation
import Foundation
import OSLog

@MainActor
final class AVFoundationAudioRecordingService: AudioRecordingServicing {
    private let captureSession = RecordingCaptureSessionCoordinator()
    private var recordingURL: URL?
    private var hasReportedCaptureFailure = false
    private let eventContinuation: AsyncStream<AudioRecordingServiceEvent>.Continuation
    private var audioSessionObservation: NotificationCenter.ObservationToken?
    private static let logger = Logger(
        subsystem: "com.tysonpitcher.ListenHere",
        category: "AudioRecording"
    )

    let events: AsyncStream<AudioRecordingServiceEvent>

    init() {
        let eventStream = AsyncStream<AudioRecordingServiceEvent>.makeStream()
        events = eventStream.stream
        eventContinuation = eventStream.continuation

        // iOS 27 distinguishes an app-requested deactivation from a system interruption.
        // Only a system interruption should stop an active ambient recording.
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
        // AVAudioApplication is the modern microphone-permission boundary. The prompt appears
        // only once; later requests return the existing authorization decision.
        Self.logger.debug("Microphone permission requested.")
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start() async throws {
        let audioSession = AVAudioSession.sharedInstance()
        Self.logger.debug("Audio recording start requested.")
        do {
            // AVAudioSession owns routing while AVCaptureSession owns the microphone sample flow.
            // Keeping both behind this service prevents SwiftUI from managing route or lifecycle.
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothHFP])
            guard try await audioSession.activate(options: []) else {
                throw RecordingError.activationFailed
            }

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("m4a")
            try await captureSession.startAudioRecording(to: url)
            recordingURL = url
            hasReportedCaptureFailure = false
            Self.logger.debug("Audio recording started in the shared capture session.")
        } catch {
            _ = try? await audioSession.deactivate(options: [.notifyOthersOnDeactivation])
            Self.logger.error("Audio recording session startup failed.")
            throw error
        }
    }

    func resumeAfterCameraSessionStarts() async throws {
        // The camera is added to the same AVCaptureSession as the microphone, so opening it does
        // not create a competing audio client. This check keeps the UI truthful if capture ended.
        guard captureSession.isAudioRecording else {
            throw RecordingError.notRecording
        }
    }

    func stop() async throws -> AudioRecording {
        guard let url = recordingURL else {
            Self.logger.error("Audio finalization was requested without an active recording.")
            throw RecordingError.notRecording
        }
        recordingURL = nil
        hasReportedCaptureFailure = false
        Self.logger.debug("Audio recording finalization requested.")

        do {
            let file = try await captureSession.finishAudioRecording()
            let data = try Data(contentsOf: file.url)
            try? FileManager.default.removeItem(at: file.url)
            _ = try? await AVAudioSession.sharedInstance()
                .deactivate(options: [.notifyOthersOnDeactivation])
            Self.logger.debug("Temporary audio recording read completed.")
            return AudioRecording(data: data, duration: file.duration)
        } catch {
            try? FileManager.default.removeItem(at: url)
            _ = try? await AVAudioSession.sharedInstance()
                .deactivate(options: [.notifyOthersOnDeactivation])
            Self.logger.error("Temporary audio recording finalization failed.")
            throw error
        }
    }

    func cancel() async {
        Self.logger.debug("Audio recording cancellation requested.")
        let url = recordingURL
        recordingURL = nil
        hasReportedCaptureFailure = false
        await captureSession.cancelAudioRecording()
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
        _ = try? await AVAudioSession.sharedInstance()
            .deactivate(options: [.notifyOthersOnDeactivation])
    }

    func meterLevel() -> AudioMeterLevel {
        guard captureSession.isAudioRecording, captureSession.isAudioCaptureHealthy else {
            if hasReportedCaptureFailure == false {
                hasReportedCaptureFailure = true
                Self.logger.error("Microphone samples stopped while the recording UI was active.")
                eventContinuation.yield(.recordingEndedUnexpectedly)
            }
            return .silence
        }
        hasReportedCaptureFailure = false
        return captureSession.meterLevel()
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
        case notRecording
    }
}

extension AVFoundationAudioRecordingService: RecordingPhotoCameraProviding {
    func makeRecordingPhotoCameraController() -> RecordingPhotoCameraController {
        RecordingPhotoCameraController(coordinator: captureSession)
    }
}
