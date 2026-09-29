import Foundation
import Testing
@testable import ListenHere

@MainActor
struct MemoryShareViewModelTests {
    @Test("A photo-and-audio memory offers video, photo, and audio sharing")
    func photoAndAudioOptionsAreAvailable() {
        let viewModel = makeViewModel(availability: .photoAndAudio)

        #expect(viewModel.options == [.video, .photo, .audio])
    }

    @Test("Photo sharing hands the original photo directly to the system share sheet")
    func photoSharingUsesOriginalPhoto() async {
        let photoURL = URL(filePath: "/tmp/photo.heic")
        let viewModel = MemoryShareViewModel(
            availability: .photo,
            photoURL: photoURL,
            audioURL: nil,
            videoExporter: MemoryVideoExporterStub()
        )

        await viewModel.prepareShare(.photo)

        #expect(viewModel.preparedShare?.url == photoURL)
        #expect(viewModel.preparedShare?.isTemporaryExport == false)
    }

    @Test("Video sharing exports a temporary combined movie and removes it when sharing ends")
    func videoSharingExportsAndCleansUpMovie() async throws {
        let outputURL = URL(filePath: "/tmp/shared-memory.mp4")
        let exporter = MemoryVideoExporterStub(outputURL: outputURL)
        let viewModel = makeViewModel(availability: .photoAndAudio, exporter: exporter)
        var observedProgress: Double?
        exporter.didReportProgress = {
            observedProgress = viewModel.preparationProgress
        }

        await viewModel.prepareShare(.video)

        #expect(observedProgress == 0.42)
        let share = try #require(viewModel.preparedShare)
        #expect(share.url == outputURL)
        #expect(share.isTemporaryExport)
        viewModel.finishSharing(share)
        #expect(exporter.discardedURLs == [outputURL])
        #expect(viewModel.preparedShare == nil)
    }

    private func makeViewModel(
        availability: MemorySharingAvailability,
        exporter: MemoryVideoExporterStub? = nil
    ) -> MemoryShareViewModel {
        let resolvedExporter = exporter ?? MemoryVideoExporterStub()
        return MemoryShareViewModel(
            availability: availability,
            photoURL: URL(filePath: "/tmp/photo.heic"),
            audioURL: URL(filePath: "/tmp/audio.m4a"),
            videoExporter: resolvedExporter
        )
    }
}

@MainActor
private final class MemoryVideoExporterStub: MemoryVideoExporting {
    private let outputURL: URL
    private(set) var discardedURLs: [URL] = []
    var didReportProgress: (() -> Void)?

    init(outputURL: URL = URL(filePath: "/tmp/shared-memory.mp4")) {
        self.outputURL = outputURL
    }

    nonisolated func exportVideo(
        photoURL _: URL,
        audioURL _: URL,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws -> URL {
        await progress(0.42)
        await MainActor.run { didReportProgress?() }
        return outputURL
    }

    func discardTemporaryExport(at url: URL) {
        discardedURLs.append(url)
    }
}
