import AVFoundation
import Foundation
import Testing
@testable import ListenHere

struct AVFoundationAudioWaveformAnalyzerTests {
    @Test("Waveform analysis downsamples decoded audio into normalized peaks")
    func extractsNormalizedSamples() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "ListenHereWaveform-\(UUID().uuidString)")
            .appendingPathExtension("caf")
        defer { try? FileManager.default.removeItem(at: url) }

        let format = try #require(
            AVAudioFormat(standardFormatWithSampleRate: 8_000, channels: 1)
        )
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = try #require(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 800)
        )
        buffer.frameLength = 800
        let channel = try #require(buffer.floatChannelData?[0])
        for frame in 0..<Int(buffer.frameLength) {
            let phase = Float(frame) / Float(buffer.frameLength) * .pi * 8
            channel[frame] = sin(phase) * (frame < 400 ? 0.25 : 1)
        }
        try file.write(from: buffer)

        let samples = try await AVFoundationAudioWaveformAnalyzer()
            .samples(for: url, targetCount: 8)

        #expect(samples.count == 8)
        #expect(samples.allSatisfy { 0...1 ~= $0 })
        #expect(samples.suffix(4).max() == 1)
        #expect((samples.prefix(4).max() ?? 0) < 0.3)
    }
}
