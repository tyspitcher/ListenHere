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

    @Test("First-use permission waits for the app to become active before recording")
    func firstUsePermissionWaitsForActiveScene() async {
        let service = ControlledPermissionRecordingServiceStub()
        let viewModel = VoiceRecordingViewModel(service: service, clock: ManualRecordingClock())
        let startTask = Task { await viewModel.start() }

        await waitUntil { service.hasPendingPermissionRequest }
        #expect(viewModel.state == .requestingPermission)
        #expect(service.startCount == 0)

        await viewModel.applicationDidBecomeInactive()
        service.resolvePermission(granted: true)
        await startTask.value

        #expect(viewModel.state == .preparingRecording)
        #expect(service.startCount == 0)

        await viewModel.applicationDidBecomeActive()

        #expect(viewModel.isRecording)
        #expect(service.startCount == 1)
    }

    @Test("Cancelling while the first permission prompt is open never starts recording")
    func cancellingDuringFirstUsePermissionPromptPreventsDelayedStart() async {
        let service = ControlledPermissionRecordingServiceStub()
        let viewModel = VoiceRecordingViewModel(service: service, clock: ManualRecordingClock())
        let startTask = Task { await viewModel.start() }

        await waitUntil { service.hasPendingPermissionRequest }
        await viewModel.applicationDidBecomeInactive()
        service.resolvePermission(granted: true)
        await startTask.value

        await viewModel.discardRecording()
        await viewModel.applicationDidBecomeActive()

        #expect(viewModel.state == .idle)
        #expect(service.startCount == 0)
        #expect(service.didCancel)
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
        #expect(viewModel.levels == [AudioMeterLevel(average: 0.6, peak: 0.8)])
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

    @Test("An unexpected recorder ending preserves the partial recording")
    func unexpectedRecorderEndPreservesRecording() async {
        let service = VoiceRecordingServiceStub()
        var completedRecordings: [AudioRecording] = []
        let viewModel = VoiceRecordingViewModel(
            service: service,
            clock: ManualRecordingClock(),
            onRecordingFinished: { completedRecordings.append($0) }
        )

        await viewModel.start()
        await Task.yield()
        service.send(.recordingEndedUnexpectedly)
        await waitUntil { completedRecordings.count == 1 }

        #expect(service.stopCount == 1)
        #expect(completedRecordings.first?.duration == 12)
        #expect(viewModel.state == .idle)
    }

    @Test("Starting the camera asks the recording service to continue the same clip")
    func cameraSessionStartKeepsRecording() async {
        let service = VoiceRecordingServiceStub()
        let viewModel = makeViewModel(service: service)

        await viewModel.start()
        await viewModel.cameraSessionDidStart()

        #expect(service.resumeAfterCameraSessionStartCount == 1)
        #expect(viewModel.isRecording)
        #expect(service.stopCount == 0)
    }

    @Test("A delayed recorder suspension is resumed without ending the clip")
    func delayedCameraSuspensionResumesRecording() async {
        let service = VoiceRecordingServiceStub()
        let viewModel = makeViewModel(service: service)

        await viewModel.start()
        await Task.yield()
        service.send(.recordingSuspendedUnexpectedly)
        await waitUntil { service.resumeAfterCameraSessionStartCount == 1 }

        #expect(viewModel.isRecording)
        #expect(service.stopCount == 0)
    }

    @Test("A camera-start audio recovery failure preserves the partial clip")
    func cameraSessionRecoveryFailurePreservesRecording() async {
        let service = VoiceRecordingServiceStub(cameraResumeShouldFail: true)
        var completedRecordings: [AudioRecording] = []
        let viewModel = VoiceRecordingViewModel(
            service: service,
            clock: ManualRecordingClock(),
            onRecordingFinished: { completedRecordings.append($0) }
        )

        await viewModel.start()
        await viewModel.cameraSessionDidStart()

        #expect(service.resumeAfterCameraSessionStartCount == 1)
        #expect(service.stopCount == 1)
        #expect(completedRecordings.count == 1)
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
    private let averageMeterLevel: Double
    private let recordingDuration: TimeInterval
    private let cameraResumeShouldFail: Bool
    private var eventContinuation: AsyncStream<AudioRecordingServiceEvent>.Continuation?
    private(set) var didCancel = false
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var resumeAfterCameraSessionStartCount = 0

    init(
        permissionGranted: Bool = true,
        meterLevel: Double = 0.25,
        recordingDuration: TimeInterval = 12,
        cameraResumeShouldFail: Bool = false
    ) {
        self.permissionGranted = permissionGranted
        averageMeterLevel = meterLevel
        self.recordingDuration = recordingDuration
        self.cameraResumeShouldFail = cameraResumeShouldFail
        let stream = AsyncStream<AudioRecordingServiceEvent>.makeStream()
        events = stream.stream
        eventContinuation = stream.continuation
    }

    func requestPermission() async -> Bool { permissionGranted }

    func start() async throws {
        startCount += 1
    }

    func resumeAfterCameraSessionStarts() async throws {
        resumeAfterCameraSessionStartCount += 1
        if cameraResumeShouldFail { throw StubError.cameraResumeFailed }
    }

    func stop() async throws -> AudioRecording {
        stopCount += 1
        return AudioRecording(data: Data("recording".utf8), duration: recordingDuration)
    }

    func cancel() async {
        didCancel = true
    }

    func meterLevel() -> AudioMeterLevel {
        AudioMeterLevel(average: averageMeterLevel, peak: min(1, averageMeterLevel + 0.2))
    }

    func send(_ event: AudioRecordingServiceEvent) {
        eventContinuation?.yield(event)
    }

    private enum StubError: Error {
        case cameraResumeFailed
    }
}

@MainActor
private final class ControlledPermissionRecordingServiceStub: AudioRecordingServicing {
    let events: AsyncStream<AudioRecordingServiceEvent>

    private var permissionContinuation: CheckedContinuation<Bool, Never>?
    private(set) var didCancel = false
    private(set) var startCount = 0

    var hasPendingPermissionRequest: Bool {
        permissionContinuation != nil
    }

    init() {
        events = AsyncStream { $0.finish() }
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            permissionContinuation = continuation
        }
    }

    func resolvePermission(granted: Bool) {
        permissionContinuation?.resume(returning: granted)
        permissionContinuation = nil
    }

    func start() async throws {
        startCount += 1
    }

    func resumeAfterCameraSessionStarts() async throws {}

    func stop() async throws -> AudioRecording {
        AudioRecording(data: Data(), duration: 1)
    }

    func cancel() async {
        didCancel = true
    }

    func meterLevel() -> AudioMeterLevel { .silence }
}
