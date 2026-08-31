// Owns waveform extraction and deliberate playback for audio already imported into a capture draft.

import Foundation
import Observation

@MainActor
@Observable
final class CaptureMediaPreviewViewModel {
    private(set) var audioPlaybackState: AudioPlaybackState = .unavailable
    private(set) var waveformSamples: [Double] = []

    var playbackProgress: Double {
        switch audioPlaybackState {
        case .playing(let elapsed, let duration), .paused(let elapsed, let duration):
            duration > 0 ? elapsed / duration : 0
        case .unavailable, .failed, .ready:
            0
        }
    }

    private let captureViewModel: CaptureViewModel
    private let audioPlaybackService: any AudioPlaybackServicing
    private let waveformAnalyzer: any AudioWaveformAnalyzing
    private var playbackRefreshTask: Task<Void, Never>?
    private var loadedAudioURL: URL?

    init(
        captureViewModel: CaptureViewModel,
        audioPlaybackService: any AudioPlaybackServicing,
        waveformAnalyzer: any AudioWaveformAnalyzing
    ) {
        self.captureViewModel = captureViewModel
        self.audioPlaybackService = audioPlaybackService
        self.waveformAnalyzer = waveformAnalyzer
    }

    func loadAudio() async {
        await resetAudio()
        guard let audioURL = captureViewModel.managedAudioURL else { return }
        loadedAudioURL = audioURL

        do {
            try await audioPlaybackService.loadAudio(at: audioURL)
            audioPlaybackState = .ready(duration: currentAudioDuration)
        } catch {
            audioPlaybackState = .unavailable
        }

        do {
            let samples = try await waveformAnalyzer.samples(for: audioURL, targetCount: 48)
            guard Task.isCancelled == false, loadedAudioURL == audioURL else { return }
            waveformSamples = samples
        } catch is CancellationError {
            return
        } catch {
            // Playback remains available when optional waveform extraction fails.
            guard loadedAudioURL == audioURL else { return }
            waveformSamples = []
        }
    }

    func togglePlayback() {
        guard case .unavailable = audioPlaybackState else {
            if audioPlaybackService.isPlaying {
                audioPlaybackService.pause()
                updatePlaybackState()
                return
            }

            do {
                try audioPlaybackService.play()
                updatePlaybackState()
                startPlaybackRefresh()
            } catch {
                audioPlaybackState = .failed
            }
            return
        }
    }

    func stopPlayback() async {
        playbackRefreshTask?.cancel()
        playbackRefreshTask = nil
        await audioPlaybackService.stop()
        if loadedAudioURL != nil {
            audioPlaybackState = .paused(elapsed: 0, duration: currentAudioDuration ?? 0)
        }
    }

    func resetAudio() async {
        playbackRefreshTask?.cancel()
        playbackRefreshTask = nil
        await audioPlaybackService.stop()
        loadedAudioURL = nil
        waveformSamples = []
        audioPlaybackState = .unavailable
    }

    func shutdown() async {
        await resetAudio()
    }

    private var currentAudioDuration: TimeInterval? {
        let duration = audioPlaybackService.duration
        return duration > 0 ? duration : captureViewModel.draft.audioDurationSeconds
    }

    private func startPlaybackRefresh() {
        playbackRefreshTask?.cancel()
        playbackRefreshTask = Task { [weak self] in
            let clock = ContinuousClock()
            while Task.isCancelled == false {
                do {
                    try await clock.sleep(for: .milliseconds(100))
                } catch {
                    return
                }
                guard Task.isCancelled == false, let self else { return }
                refreshPlayback()
            }
        }
    }

    private func refreshPlayback() {
        guard audioPlaybackService.isPlaying else {
            playbackRefreshTask?.cancel()
            playbackRefreshTask = nil
            audioPlaybackState = .ready(duration: currentAudioDuration)
            return
        }
        updatePlaybackState()
    }

    private func updatePlaybackState() {
        let elapsed = audioPlaybackService.currentTime
        let duration = audioPlaybackService.duration
        audioPlaybackState = audioPlaybackService.isPlaying
            ? .playing(elapsed: elapsed, duration: duration)
            : .paused(elapsed: elapsed, duration: duration)
    }

#if DEBUG
    func setPreviewState(
        playbackState: AudioPlaybackState,
        samples: [Double]
    ) {
        audioPlaybackState = playbackState
        waveformSamples = samples
    }
#endif
}
