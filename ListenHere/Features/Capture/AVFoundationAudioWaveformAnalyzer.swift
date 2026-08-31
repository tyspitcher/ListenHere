// Extracts a compact waveform from local audio without performing decoding on the main actor.

import AVFoundation

struct AVFoundationAudioWaveformAnalyzer: AudioWaveformAnalyzing {
    nonisolated func samples(for url: URL, targetCount: Int) async throws -> [Double] {
        guard targetCount > 0 else { return [] }

        // AVAudioFile decodes compressed input into float PCM. Chunking avoids holding an entire
        // five-minute recording in memory, and this async nonisolated boundary stays off MainActor.
        let file = try AVAudioFile(
            forReading: url,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        let totalFrames = max(1, file.length)
        let capacity: AVAudioFrameCount = 4_096
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: capacity
        ) else {
            return []
        }

        var peaks = Array(repeating: Float.zero, count: targetCount)
        var frameOffset: AVAudioFramePosition = 0

        while frameOffset < totalFrames {
            try Task.checkCancellation()
            try file.read(into: buffer, frameCount: capacity)
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0, let channels = buffer.floatChannelData else { break }

            for frame in 0..<frameLength {
                var amplitude = Float.zero
                for channel in 0..<Int(buffer.format.channelCount) {
                    amplitude = max(amplitude, abs(channels[channel][frame]))
                }
                let absoluteFrame = frameOffset + AVAudioFramePosition(frame)
                let bucket = min(
                    targetCount - 1,
                    Int(Double(absoluteFrame) / Double(totalFrames) * Double(targetCount))
                )
                peaks[bucket] = max(peaks[bucket], amplitude)
            }

            frameOffset += AVAudioFramePosition(frameLength)
        }

        let largestPeak = peaks.max() ?? 0
        guard largestPeak > 0 else { return Array(repeating: 0, count: targetCount) }
        return peaks.map { Double($0 / largestPeak) }
    }
}
