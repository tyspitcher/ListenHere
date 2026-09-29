// Builds a shareable still-image video with the memory's ambient recording.

import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo
import Foundation

struct AVFoundationMemoryVideoExporter: MemoryVideoExporting {
    private enum ExportError: Error {
        case invalidPhoto
        case missingAudioTrack
        case couldNotCreateWriter
        case couldNotCreatePixelBuffer
        case couldNotFinish
    }

    private let outputSize = CGSize(width: 1_080, height: 1_920)
    private let framesPerSecond: Int32 = 2

    nonisolated init() {}

    // AVAssetWriter combines rendered still-image video frames and decoded audio samples into one
    // portable MP4. Keeping this AVFoundation work behind an export protocol lets the detail UI
    // stay focused on sharing state and keeps the temporary-file lifecycle testable.
    nonisolated func exportVideo(
        photoURL: URL,
        audioURL: URL,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws -> URL {
        await progress(0)
        return try await Task.detached(priority: .userInitiated) {
            try await export(
                photoURL: photoURL,
                audioURL: audioURL,
                progress: progress
            )
        }.value
    }

    func discardTemporaryExport(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    nonisolated private func export(
        photoURL: URL,
        audioURL: URL,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws -> URL {
        try Task.checkCancellation()
        guard let image = CIImage(
            contentsOf: photoURL,
            options: [
                .applyOrientationProperty: true,
                .toneMapHDRtoSDR: true
            ]
        ) else {
            throw ExportError.invalidPhoto
        }
        await progress(0.02)

        let audioAsset = AVURLAsset(url: audioURL)
        guard let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else {
            throw ExportError.missingAudioTrack
        }
        let duration = try await audioAsset.load(.duration)
        guard duration.isNumeric, duration > .zero else {
            throw ExportError.missingAudioTrack
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appending(path: "ListenHere-\(UUID().uuidString).mp4")
        var exportSucceeded = false
        defer {
            if exportSucceeded == false {
                try? FileManager.default.removeItem(at: outputURL)
            }
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: outputSize.width,
                AVVideoHeightKey: outputSize.height,
                AVVideoColorPropertiesKey: [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
                ],
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 4_000_000
                ]
            ]
        )
        let pixelBufferAttributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
            size: CVImageSize(width: Int(outputSize.width), height: Int(outputSize.height)),
            compatibility: [.cgImage, .metalTexture]
        )
        let videoReceiver = writer.inputPixelBufferReceiver(
            for: videoInput,
            pixelBufferAttributes: pixelBufferAttributes
        )

        let audioInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128_000
            ]
        )
        let audioReceiver = writer.inputReceiver(for: audioInput)

        let reader = try AVAssetReader(asset: audioAsset)
        let readerOutput = AVAssetReaderTrackOutput(
            track: audioTrack,
            outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM]
        )
        let audioProvider = reader.outputProvider(for: readerOutput)

        do {
            try writer.start()
            try reader.start()
            writer.startSession(atSourceTime: .zero)

            let pixelBuffer = try makePixelBuffer(
                for: image,
                pool: videoReceiver.pixelBufferPool,
                attributes: pixelBufferAttributes
            )
            await progress(0.05)

            // Asset writers interleave their inputs. Send the still-image frames and audio
            // concurrently so back-pressure on one track cannot prevent the other from advancing.
            async let videoWriting: Void = appendVideo(
                pixelBuffer: pixelBuffer,
                duration: duration,
                receiver: videoReceiver,
                progress: progress
            )
            async let audioWriting: Void = appendAudio(
                provider: audioProvider,
                receiver: audioReceiver
            )
            _ = try await (videoWriting, audioWriting)

            await progress(0.98)
            await writer.finishWriting()
            guard writer.status == .completed else {
                throw writer.error ?? ExportError.couldNotFinish
            }

            exportSucceeded = true
            await progress(1)
            return outputURL
        } catch {
            reader.cancelReading()
            writer.cancelWriting()
            throw error
        }
    }

    nonisolated private func appendVideo(
        pixelBuffer: CVReadOnlyPixelBuffer,
        duration: CMTime,
        receiver: AVAssetWriterInput.PixelBufferReceiver,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws {
        defer { receiver.finish() }

        let frameDuration = CMTime(value: 1, timescale: framesPerSecond)
        let durationSeconds = CMTimeGetSeconds(duration)
        var presentationTime = CMTime.zero
        var lastReportedPercentage = -1

        while presentationTime < duration {
            try Task.checkCancellation()
            try await receiver.append(pixelBuffer, with: presentationTime)
            presentationTime = presentationTime + frameDuration

            let videoProgress = min(
                max(CMTimeGetSeconds(presentationTime) / durationSeconds, 0),
                1
            )
            let percentage = Int((videoProgress * 100).rounded(.down))
            if percentage > lastReportedPercentage {
                lastReportedPercentage = percentage
                await progress(0.05 + (videoProgress * 0.9))
            }
        }
    }

    nonisolated private func appendAudio(
        provider: AVAssetReaderOutput.Provider<CMReadySampleBuffer<CMSampleBuffer.DynamicContent>>,
        receiver: AVAssetWriterInput.SampleBufferReceiver
    ) async throws {
        defer { receiver.finish() }

        while let sampleBuffer = try await provider.next() {
            try Task.checkCancellation()
            try await receiver.append(sampleBuffer)
        }
    }

    nonisolated private func makePixelBuffer(
        for image: CIImage,
        pool: CVMutablePixelBuffer.Pool?,
        attributes: CVPixelBufferCreationAttributes
    ) throws -> CVReadOnlyPixelBuffer {
        var pixelBuffer: CVMutablePixelBuffer
        if let pool {
            pixelBuffer = try pool.makeMutablePixelBuffer()
        } else {
            pixelBuffer = try CVMutablePixelBuffer(attributes)
        }

        let outputRect = CGRect(origin: .zero, size: outputSize)
        let normalizedImage = image.transformed(
            by: CGAffineTransform(
                translationX: -image.extent.minX,
                y: -image.extent.minY
            )
        )
        let scale = min(
            outputSize.width / normalizedImage.extent.width,
            outputSize.height / normalizedImage.extent.height
        )
        let scaledImage = normalizedImage.transformed(
            by: CGAffineTransform(scaleX: scale, y: scale)
        )
        let centeredImage = scaledImage.transformed(
            by: CGAffineTransform(
                translationX: (outputSize.width - scaledImage.extent.width) / 2,
                y: (outputSize.height - scaledImage.extent.height) / 2
            )
        )
        let background = CIImage.black.cropped(to: outputRect)
        let composedImage = centeredImage.composited(over: background)

        // Core Image decodes and color-matches camera JPEG, HEIC, and HDR-backed sources,
        // then renders directly into the AVFoundation pixel buffer. Borrowing the underlying
        // buffer does not lock its base address, so an iPhone's GPU renderer can write the frame.
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        pixelBuffer.withUnsafeBuffer { buffer in
            CIContext().render(
                composedImage,
                to: buffer,
                bounds: outputRect,
                colorSpace: colorSpace
            )
        }

        return CVReadOnlyPixelBuffer(pixelBuffer)
    }
}
