// Defines the recording capability consumed by the capture presentation layer.

import Foundation

enum AudioRecordingServiceEvent: Sendable {
    case interruptionBegan
    case routeChanged
    case recordingSuspendedUnexpectedly
    case recordingEndedUnexpectedly
}

struct AudioMeterLevel: Equatable, Sendable {
    let average: Double
    let peak: Double

    static let silence = AudioMeterLevel(average: 0, peak: 0)
}

@MainActor
protocol AudioRecordingServicing: AnyObject {
    var events: AsyncStream<AudioRecordingServiceEvent> { get }

    func requestPermission() async -> Bool
    func start() async throws
    func resumeAfterCameraSessionStarts() async throws
    func stop() async throws -> AudioRecording
    func cancel() async
    func meterLevel() -> AudioMeterLevel
}

/// Supplies the UIKit/AVFoundation camera adapter that shares the active recording session.
/// Test and preview audio services intentionally do not need to implement this capability.
@MainActor
protocol RecordingPhotoCameraProviding: AnyObject {
    func makeRecordingPhotoCameraController() -> RecordingPhotoCameraController
}
