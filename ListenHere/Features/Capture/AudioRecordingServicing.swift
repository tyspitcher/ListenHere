// Defines the recording capability consumed by the capture presentation layer.

import Foundation

enum AudioRecordingServiceEvent: Sendable {
    case interruptionBegan
    case routeChanged
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
    func stop() async throws -> AudioRecording
    func cancel() async
    func meterLevel() -> AudioMeterLevel
}
