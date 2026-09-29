import AVFoundation
import CoreImage
import Foundation
import Testing
import UIKit
@testable import ListenHere

@MainActor
struct AVFoundationMemoryVideoExporterTests {
    @Test("Video export renders a managed HEIC photo throughout the audio duration")
    func exportCompletesWithVideoAndAudioTracks() async throws {
        let inputDirectory = FileManager.default.temporaryDirectory
            .appending(path: "ListenHereExporterTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: inputDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: inputDirectory) }

        let photoURL = inputDirectory.appending(path: "photo.heic")
        let audioURL = inputDirectory.appending(path: "audio.caf")
        try makePhoto(at: photoURL)
        try makeAudio(at: audioURL)

        let exporter = AVFoundationMemoryVideoExporter()
        var reportedProgress: [Double] = []
        let outputURL = try await exporter.exportVideo(
            photoURL: photoURL,
            audioURL: audioURL,
            progress: { reportedProgress.append($0) }
        )
        defer { exporter.discardTemporaryExport(at: outputURL) }

        let exportedAsset = AVURLAsset(url: outputURL)
        let videoTracks = try await exportedAsset.loadTracks(withMediaType: .video)
        let audioTracks = try await exportedAsset.loadTracks(withMediaType: .audio)
        let imageGenerator = AVAssetImageGenerator(asset: exportedAsset)
        let firstFrame = try await imageGenerator.image(at: .zero).image
        let laterFrame = try await imageGenerator
            .image(at: CMTime(seconds: 1.5, preferredTimescale: 600))
            .image

        #expect(FileManager.default.fileExists(atPath: outputURL.path))
        #expect(videoTracks.count == 1)
        #expect(audioTracks.count == 1)
        #expect(averageColorIntensity(of: firstFrame) > 40)
        #expect(averageColorIntensity(of: laterFrame) > 40)
        #expect(reportedProgress.first == 0)
        #expect(reportedProgress.last == 1)
    }

    private func makePhoto(at url: URL) throws {
        let image = CIImage(color: CIColor(red: 0, green: 0.3, blue: 1))
            .cropped(to: CGRect(x: 0, y: 0, width: 120, height: 160))
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        try CIContext().writeHEIFRepresentation(
            of: image,
            to: url,
            format: .RGBA8,
            colorSpace: colorSpace
        )
    }

    private func makeAudio(at url: URL) throws {
        let format = try #require(
            AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        )
        let frameCount = AVAudioFrameCount(format.sampleRate * 2)
        let buffer = try #require(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        )
        buffer.frameLength = frameCount
        buffer.floatChannelData?[0].initialize(repeating: 0, count: Int(frameCount))

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    private func averageColorIntensity(of image: CGImage) -> Int {
        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return 0
        }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return Int(pixel[0]) + Int(pixel[1]) + Int(pixel[2])
    }
}
