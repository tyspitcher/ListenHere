import Foundation
import Testing
@testable import ListenHere

@MainActor
struct VoiceRecordingViewModelTests {
    @Test("Permission denial produces an actionable failed state")
    func permissionDenial() async {
        let service = VoiceRecordingServiceStub(permissionGranted: false)
        let viewModel = makeViewModel(service: service)

        await viewModel.start()

        #expect(viewModel.state == .failed(.permissionDenied))
        #expect(service.startCount == 0)
    }

    @Test("Stopping imports the completed recording exactly once")
    func stoppingCompletesOnce() async {
        let service = VoiceRecordingServiceStub()
        let clock = ManualRecordingClock()
        var completedRecordings: [AudioRecording] = []
        let viewModel = VoiceRecordingViewModel(
            service: service,
            clock: clock,
            onRecordingFinished: { completedRecordings.append($0) }
        )

        await viewModel.start()
        await viewModel.stop()
        await viewModel.stop()

        #expect(service.stopCount == 1)
        #expect(completedRecordings.count == 1)
        #expect(completedRecordings.first?.duration == 12)
        #expect(viewModel.state == .idle)
    }

    @Test("A zero-duration recording is rejected without importing audio")
    func zeroDurationRecordingIsRejected() async {
        let service = VoiceRecordingServiceStub(recordingDuration: 0)
        var completionCount = 0
        let viewModel = VoiceRecordingViewModel(
            service: service,
            clock: ManualRecordingClock()
        ) { _ in
            completionCount += 1
        }

        await viewModel.start()
        await viewModel.stop()

        #expect(viewModel.state == .failed(.couldNotFinish))
        #expect(completionCount == 0)
    }

    @Test("Elapsed ticks update the timer and live waveform")
    func elapsedTicksUpdatePresentation() async {
        let service = VoiceRecordingServiceStub(meterLevel: 0.6)
        let clock = ManualRecordingClock()
        let viewModel = makeViewModel(service: service, clock: clock)

        await viewModel.start()
        await Task.yield()
        clock.send(12.4)
        await Task.yield()

        #expect(viewModel.elapsed == 12.4)
        #expect(viewModel.elapsedDescription == "0:12")
        #expect(viewModel.levels == [0.6])
    }

    @Test("The five-minute limit automatically preserves the recording")
    func maximumDurationAutoStops() async {
        let service = VoiceRecordingServiceStub()
        let clock = ManualRecordingClock()
        var completionCount = 0
        let viewModel = VoiceRecordingViewModel(
            service: service,
            clock: clock,
            maximumDuration: 300,
            onRecordingFinished: { _ in completionCount += 1 }
        )

        await viewModel.start()
        await Task.yield()
        clock.send(300)
        await waitUntil { completionCount == 1 }

        #expect(service.stopCount == 1)
        #expect(completionCount == 1)
        #expect(viewModel.notice == "Recording stopped at the five-minute limit and was added to your memory.")
    }

    @Test("An audio-session event preserves a partial recording")
    func interruptionPreservesRecording() async {
        let service = VoiceRecordingServiceStub()
        var completionCount = 0
        let viewModel = VoiceRecordingViewModel(
            service: service,
            clock: ManualRecordingClock(),
            onRecordingFinished: { _ in completionCount += 1 }
        )

        await viewModel.start()
        await Task.yield()
        service.send(.interruptionBegan)
        await waitUntil { completionCount == 1 }

        #expect(service.stopCount == 1)
        #expect(completionCount == 1)
        #expect(viewModel.state == .idle)
    }

    @Test("Discarding an active recording stops its service without importing")
    func discardingActiveRecording() async {
        let service = VoiceRecordingServiceStub()
        var completionCount = 0
        let viewModel = VoiceRecordingViewModel(
            service: service,
            clock: ManualRecordingClock(),
            onRecordingFinished: { _ in completionCount += 1 }
        )

        await viewModel.start()
        await viewModel.discardRecording()

        #expect(service.didCancel)
        #expect(viewModel.isRecording == false)
        #expect(viewModel.hasUnsavedRecording == false)
        #expect(completionCount == 0)
    }

    private func makeViewModel(
        service: VoiceRecordingServiceStub,
        clock: ManualRecordingClock? = nil
    ) -> VoiceRecordingViewModel {
        VoiceRecordingViewModel(service: service, clock: clock ?? ManualRecordingClock())
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            await Task.yield()
        }
    }
}

@MainActor
private final class ManualRecordingClock: RecordingClock {
    private var continuation: AsyncStream<TimeInterval>.Continuation?

    func elapsedTimeStream() -> AsyncStream<TimeInterval> {
        AsyncStream { continuation in self.continuation = continuation }
    }

    func send(_ elapsed: TimeInterval) {
        continuation?.yield(elapsed)
    }
}

@MainActor
private final class VoiceRecordingServiceStub: AudioRecordingServicing {
    let events: AsyncStream<AudioRecordingServiceEvent>

    private let permissionGranted: Bool
    private let meterLevel: Double
    private let recordingDuration: TimeInterval
    private var eventContinuation: AsyncStream<AudioRecordingServiceEvent>.Continuation?
    private(set) var didCancel = false
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(
        permissionGranted: Bool = true,
        meterLevel: Double = 0.25,
        recordingDuration: TimeInterval = 12
    ) {
        self.permissionGranted = permissionGranted
        self.meterLevel = meterLevel
        self.recordingDuration = recordingDuration
        let stream = AsyncStream<AudioRecordingServiceEvent>.makeStream()
        events = stream.stream
        eventContinuation = stream.continuation
    }

    func requestPermission() async -> Bool { permissionGranted }

    func start() async throws {
        startCount += 1
    }

    func stop() async throws -> AudioRecording {
        stopCount += 1
        return AudioRecording(data: Data("recording".utf8), duration: recordingDuration)
    }

    func cancel() async {
        didCancel = true
    }

    func normalizedMeterLevel() -> Double { meterLevel }

    func send(_ event: AudioRecordingServiceEvent) {
        eventContinuation?.yield(event)
    }
}
