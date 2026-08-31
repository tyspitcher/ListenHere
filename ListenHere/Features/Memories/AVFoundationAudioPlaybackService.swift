// Wraps AVAudioPlayer so AVFoundation playback and its audio-session lifecycle stay out of feature views.

import AVFoundation

@MainActor
final class AVFoundationAudioPlaybackService: NSObject, AudioPlaybackServicing, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    var currentTime: TimeInterval { player?.currentTime ?? 0 }
    var duration: TimeInterval { player?.duration ?? 0 }
    var isPlaying: Bool { player?.isPlaying ?? false }

    func loadAudio(at url: URL) async throws {
        await stop()
        // AVAudioPlayer performs local, file-backed playback. It is kept behind this service so
        // Memory Detail stays independent of AVFoundation and can use a deterministic test fake.
        // AVAudioSession activates the app's intentional playback route after a recording flow
        // has deactivated its microphone session; the detail screen never starts playback itself.
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        // Route negotiation may block when another app or an external device owns audio.
        // iOS 27's async API keeps that work from stalling the SwiftUI main actor.
        guard try await session.activate(options: []) else {
            throw AudioPlaybackServiceError.couldNotStart
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            self.player = player
        } catch {
            _ = try? await session.deactivate(options: [.notifyOthersOnDeactivation])
            throw error
        }
    }

    func play() throws {
        guard let player else { throw AudioPlaybackServiceError.audioNotLoaded }
        guard player.play() else { throw AudioPlaybackServiceError.couldNotStart }
    }

    func pause() {
        player?.pause()
    }

    func stop() async {
        player?.stop()
        player = nil
        _ = try? await AVAudioSession.sharedInstance()
            .deactivate(options: [.notifyOthersOnDeactivation])
    }

    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        player?.currentTime = 0
    }
}
