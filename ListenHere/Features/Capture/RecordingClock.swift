// Supplies deterministic elapsed-time ticks to the recording presentation model.

import Foundation

@MainActor
protocol RecordingClock: AnyObject {
    func elapsedTimeStream() -> AsyncStream<TimeInterval>
}

@MainActor
final class ContinuousRecordingClock: RecordingClock {
    private let interval: Duration

    init(interval: Duration = .milliseconds(100)) {
        self.interval = interval
    }

    func elapsedTimeStream() -> AsyncStream<TimeInterval> {
        AsyncStream { continuation in
            let task = Task { @MainActor [interval] in
                let clock = ContinuousClock()
                let start = clock.now

                while Task.isCancelled == false {
                    do {
                        try await clock.sleep(for: interval)
                    } catch {
                        return
                    }

                    let elapsed = start.duration(to: clock.now).components
                    continuation.yield(
                        Double(elapsed.seconds)
                            + Double(elapsed.attoseconds) / 1_000_000_000_000_000_000
                    )
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
