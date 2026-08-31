// Coordinates microphone permission, recording lifecycle, metering, elapsed time, and finalization.

import Foundation
import Observation

@MainActor
@Observable
final class VoiceRecordingViewModel {
    private(set) var state: VoiceRecordingState = .idle
    private(set) var notice: String?

    var isRecording: Bool {
        if case .recording = state { true } else { false }
    }

    var hasUnsavedRecording: Bool {
        switch state {
        case .requestingPermission, .recording, .finalizing:
            true
        case .idle, .failed:
            false
        }
    }

    var elapsed: TimeInterval {
        if case .recording(let elapsed, _) = state { elapsed } else { 0 }
    }

    var levels: [Double] {
        if case .recording(_, let levels) = state { levels } else { [] }
    }

    var elapsedDescription: String {
        Self.formattedTime(elapsed)
    }

    var failureMessage: String? {
        if case .failed(let failure) = state { failure.message } else { nil }
    }

    private let maximumDuration: TimeInterval
    private let service: any AudioRecordingServicing
    private let clock: any RecordingClock
    private let onRecordingFinished: (AudioRecording) -> Void
    private var elapsedTimeTask: Task<Void, Never>?
    private var serviceEventTask: Task<Void, Never>?
    private var operationGeneration = 0

    init(
        service: any AudioRecordingServicing,
        clock: any RecordingClock,
        maximumDuration: TimeInterval = 5 * 60,
        onRecordingFinished: @escaping (AudioRecording) -> Void = { _ in }
    ) {
        self.service = service
        self.clock = clock
        self.maximumDuration = maximumDuration
        self.onRecordingFinished = onRecordingFinished
    }

    func start() async {
        guard canStart else { return }
        operationGeneration += 1
        let generation = operationGeneration
        notice = nil
        state = .requestingPermission

        guard await service.requestPermission() else {
            guard generation == operationGeneration, case .requestingPermission = state else { return }
            state = .failed(.permissionDenied)
            return
        }
        guard generation == operationGeneration, case .requestingPermission = state else { return }

        do {
            try await service.start()
            guard generation == operationGeneration, case .requestingPermission = state else {
                await service.cancel()
                return
            }
            state = .recording(elapsed: 0, levels: [])
            startElapsedTimeUpdates()
            startObservingServiceEvents()
        } catch {
            guard generation == operationGeneration else { return }
            state = .failed(.couldNotStart)
        }
    }

    func stop() async {
        await finishRecording(reason: .user)
    }

    func stopForLifecycleEvent() async {
        await finishRecording(reason: .lifecycle)
    }

    func discardRecording() async {
        operationGeneration += 1
        cancelTasks()
        state = .idle
        notice = nil
        await service.cancel()
    }

    func acknowledgeFailure() {
        guard case .failed = state else { return }
        state = .idle
    }

    func acknowledgeNotice() {
        notice = nil
    }

    func shutdown() async {
        operationGeneration += 1
        cancelTasks()
        await service.cancel()
    }

    private var canStart: Bool {
        switch state {
        case .idle, .failed:
            true
        case .requestingPermission, .recording, .finalizing:
            false
        }
    }

    private func startElapsedTimeUpdates() {
        elapsedTimeTask?.cancel()
        elapsedTimeTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for await elapsed in clock.elapsedTimeStream() {
                guard Task.isCancelled == false, case .recording(_, let existingLevels) = state else {
                    return
                }

                var updatedLevels = existingLevels
                updatedLevels.append(service.normalizedMeterLevel())
                if updatedLevels.count > 48 {
                    updatedLevels.removeFirst(updatedLevels.count - 48)
                }
                state = .recording(elapsed: min(elapsed, maximumDuration), levels: updatedLevels)

                if elapsed >= maximumDuration {
                    await finishRecording(reason: .maximumDuration)
                    return
                }
            }
        }
    }

    private func startObservingServiceEvents() {
        serviceEventTask?.cancel()
        serviceEventTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await _ in service.events {
                guard Task.isCancelled == false else { return }
                await finishRecording(reason: .lifecycle)
            }
        }
    }

    private func finishRecording(reason: FinishReason) async {
        guard case .recording = state else { return }
        operationGeneration += 1
        let generation = operationGeneration
        state = .finalizing
        cancelTasks()

        do {
            let recording = try await service.stop()
            // The finishing request may originate from the metering or interruption task. Those
            // tasks are intentionally cancelled above; the generation token distinguishes that
            // expected cancellation from a newer discard or shutdown operation.
            guard generation == operationGeneration else { return }
            guard recording.duration > 0 else {
                state = .failed(.couldNotFinish)
                return
            }
            onRecordingFinished(recording)
            state = .idle
            notice = reason.notice
        } catch {
            guard generation == operationGeneration else { return }
            await service.cancel()
            state = .failed(.couldNotFinish)
        }
    }

    private func cancelTasks() {
        elapsedTimeTask?.cancel()
        elapsedTimeTask = nil
        serviceEventTask?.cancel()
        serviceEventTask = nil
    }

    private static func formattedTime(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return seconds < 10 ? "\(minutes):0\(seconds)" : "\(minutes):\(seconds)"
    }

#if DEBUG
    func setPreviewState(_ previewState: VoiceRecordingState) {
        state = previewState
    }
#endif
}

private extension VoiceRecordingViewModel {
    enum FinishReason {
        case user
        case maximumDuration
        case lifecycle

        var notice: String? {
            switch self {
            case .user:
                nil
            case .maximumDuration:
                "Recording stopped at the five-minute limit and was added to your memory."
            case .lifecycle:
                "Recording stopped when the audio session changed and the captured sound was preserved."
            }
        }
    }
}
