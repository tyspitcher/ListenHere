// Coordinates one AVFoundation capture graph for ambient audio and still photos.

import AVFoundation
import Foundation

final class RecordingCaptureSessionCoordinator: NSObject {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(
        label: "com.tysonpitcher.ListenHere.recordingCaptureSession"
    )
    private let sampleWriter = RecordingAudioSampleWriter()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var audioInput: AVCaptureDeviceInput?
    private var videoInput: AVCaptureDeviceInput?
    private var cameraDevice: AVCaptureDevice?
    private var captureCompletion: ((RecordingPhotoCameraController.CaptureResult) -> Void)?

    var isAudioRecording: Bool {
        sampleWriter.isRecording
    }

    var isAudioCaptureHealthy: Bool {
        sampleWriter.isReceivingSamples
    }

    // iOS does not offer AVCaptureAudioFileOutput. AVCaptureAudioDataOutput supplies microphone
    // samples to AVAssetWriter instead, allowing audio and AVCapturePhotoOutput to live in one
    // capture session without two clients competing for the device microphone.
    func startAudioRecording(to url: URL) async throws {
        try sampleWriter.prepare(toWrite: url)

        do {
            try await withCheckedThrowingContinuation { continuation in
                sessionQueue.async { [self] in
                    do {
                        try configureAudioIfNeeded()
                        if session.isRunning == false {
                            session.startRunning()
                        }
                        guard session.isRunning else {
                            throw SessionError.couldNotStart
                        }
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            await sampleWriter.cancel()
            throw error
        }
    }

    func finishAudioRecording() async throws -> RecordingAudioFile {
        do {
            let result = try await sampleWriter.finish()
            await stopSessionAndResetCamera()
            return result
        } catch {
            await stopSessionAndResetCamera()
            throw error
        }
    }

    func cancelAudioRecording() async {
        await sampleWriter.cancel()
        await stopSessionAndResetCamera()
    }

    func meterLevel() -> AudioMeterLevel {
        guard let channel = audioOutput.connection(with: .audio)?.audioChannels.first else {
            return .silence
        }
        return AudioMeterLevel(
            average: Self.normalizedPower(channel.averagePowerLevel),
            peak: Self.normalizedPower(channel.peakHoldLevel)
        )
    }

    func startCamera(
        onReady: @escaping (RecordingPhotoCameraCapabilities) -> Void,
        onFailure: @escaping () -> Void
    ) {
        sessionQueue.async { [self] in
            do {
                let capabilities = try configureCameraIfNeeded()
                DispatchQueue.main.async { onReady(capabilities) }
            } catch {
                DispatchQueue.main.async { onFailure() }
            }
        }
    }

    func stopCamera() {
        sessionQueue.async { [self] in
            captureCompletion = nil
            guard let videoInput else { return }
            session.beginConfiguration()
            session.removeInput(videoInput)
            if session.outputs.contains(where: { $0 === photoOutput }) {
                session.removeOutput(photoOutput)
            }
            session.commitConfiguration()
            self.videoInput = nil
            cameraDevice = nil
        }
    }

    func capturePhoto(
        flashMode: RecordingCameraFlashMode,
        completion: @escaping (RecordingPhotoCameraController.CaptureResult) -> Void
    ) {
        sessionQueue.async { [self] in
            guard session.isRunning, captureCompletion == nil else {
                DispatchQueue.main.async { completion(.failure) }
                return
            }

            captureCompletion = completion
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            if photoOutput.supportedFlashModes.contains(flashMode.avFoundationValue) {
                settings.flashMode = flashMode.avFoundationValue
            }
            // iOS honors regional shutter-sound requirements. Where suppression is supported,
            // silence the system sound so it is not captured in the ambient recording.
            if photoOutput.isShutterSoundSuppressionSupported {
                settings.isShutterSoundSuppressionEnabled = true
            }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func focus(at point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let camera = self?.cameraDevice else { return }
            do {
                try camera.lockForConfiguration()
                defer { camera.unlockForConfiguration() }
                if camera.isFocusPointOfInterestSupported, camera.isFocusModeSupported(.autoFocus) {
                    camera.focusPointOfInterest = point
                    camera.focusMode = .autoFocus
                }
                if camera.isExposurePointOfInterestSupported,
                   camera.isExposureModeSupported(.continuousAutoExposure) {
                    camera.exposurePointOfInterest = point
                    camera.exposureMode = .continuousAutoExposure
                    camera.setExposureTargetBias(0)
                }
            } catch {
                return
            }
        }
    }

    func setZoomFactor(_ factor: Double) {
        sessionQueue.async { [weak self] in
            guard let self, let camera = cameraDevice else { return }
            _ = applyZoomFactor(factor, to: camera)
        }
    }

    func changeZoom(by scale: CGFloat, completion: @escaping (Double) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, let camera = cameraDevice else { return }
            let factor = Double(camera.videoZoomFactor * scale)
            let appliedFactor = applyZoomFactor(factor, to: camera)
            DispatchQueue.main.async { completion(appliedFactor) }
        }
    }

    private func configureAudioIfNeeded() throws {
        guard audioInput == nil else { return }
        guard let microphone = AVCaptureDevice.default(for: .audio) else {
            throw SessionError.noMicrophone
        }

        let input = try AVCaptureDeviceInput(device: microphone)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }
        // ListenHere configures AVAudioSession itself so route and interruption policy remain
        // behind the recording-service boundary rather than being changed implicitly by capture.
        session.automaticallyConfiguresApplicationAudioSession = false
        guard session.canAddInput(input), session.canAddOutput(audioOutput) else {
            throw SessionError.configurationFailed
        }
        session.addInput(input)
        session.addOutput(audioOutput)
        audioOutput.setSampleBufferDelegate(sampleWriter, queue: sampleWriter.queue)
        audioInput = input
    }

    private func configureCameraIfNeeded() throws -> RecordingPhotoCameraCapabilities {
        if let cameraDevice, videoInput != nil {
            return capabilities(for: cameraDevice)
        }
        guard sampleWriter.isRecording, let camera = Self.preferredBackCamera() else {
            throw SessionError.noCamera
        }

        let input = try AVCaptureDeviceInput(device: camera)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
            throw SessionError.configurationFailed
        }
        session.addInput(input)
        session.addOutput(photoOutput)
        try applyDefaultZoom(to: camera)
        videoInput = input
        cameraDevice = camera
        return capabilities(for: camera)
    }

    private func stopSessionAndResetCamera() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [self] in
                captureCompletion = nil
                if session.isRunning {
                    session.stopRunning()
                }
                session.beginConfiguration()
                if let videoInput {
                    session.removeInput(videoInput)
                }
                if session.outputs.contains(where: { $0 === photoOutput }) {
                    session.removeOutput(photoOutput)
                }
                session.commitConfiguration()
                self.videoInput = nil
                cameraDevice = nil
                continuation.resume()
            }
        }
    }

    private func capabilities(for camera: AVCaptureDevice) -> RecordingPhotoCameraCapabilities {
        let maximumZoom = maximumZoomFactor(for: camera)
        let multiplier = Double(camera.displayVideoZoomFactorMultiplier)
        let supportedFlashValues = Set(photoOutput.supportedFlashModes)
        let flashModes = RecordingCameraFlashMode.allCases.filter {
            supportedFlashValues.contains($0.avFoundationValue)
        }

        return RecordingPhotoCameraCapabilities(
            maximumZoomFactor: maximumZoom,
            zoomOptions: zoomOptions(for: camera, displayMultiplier: multiplier),
            flashModes: flashModes.isEmpty ? [.off] : flashModes,
            initialZoomFactor: min(Double(camera.videoZoomFactor), maximumZoom)
        )
    }

    @discardableResult
    private func applyZoomFactor(_ factor: Double, to camera: AVCaptureDevice) -> Double {
        let minimum = Double(camera.minAvailableVideoZoomFactor)
        let maximum = maximumZoomFactor(for: camera)
        let clampedFactor = min(max(factor, minimum), maximum)
        do {
            try camera.lockForConfiguration()
            camera.videoZoomFactor = CGFloat(clampedFactor)
            camera.unlockForConfiguration()
            return clampedFactor
        } catch {
            return Double(camera.videoZoomFactor)
        }
    }

    private func applyDefaultZoom(to camera: AVCaptureDevice) throws {
        let multiplier = max(Double(camera.displayVideoZoomFactorMultiplier), 0.01)
        let defaultFactor = min(
            max(1 / multiplier, Double(camera.minAvailableVideoZoomFactor)),
            maximumZoomFactor(for: camera)
        )
        try camera.lockForConfiguration()
        camera.videoZoomFactor = CGFloat(defaultFactor)
        camera.unlockForConfiguration()
    }

    private func maximumZoomFactor(for camera: AVCaptureDevice) -> Double {
        let maximum = Double(camera.maxAvailableVideoZoomFactor)
        let recommendedMaximum = camera.activeFormat.systemRecommendedVideoZoomRange
            .map { Double($0.upperBound) }
            ?? maximum
        return max(Double(camera.minAvailableVideoZoomFactor), min(maximum, recommendedMaximum))
    }

    private func zoomOptions(
        for camera: AVCaptureDevice,
        displayMultiplier: Double
    ) -> [RecordingCameraZoomOption] {
        let minimum = Double(camera.minAvailableVideoZoomFactor)
        let maximum = maximumZoomFactor(for: camera)
        let oneTimesFactor = min(max(1 / max(displayMultiplier, 0.01), minimum), maximum)
        let switchOverFactors = camera.virtualDeviceSwitchOverVideoZoomFactors.map(\.doubleValue)
        let nativeResolutionFactors = camera.activeFormat.secondaryNativeResolutionZoomFactors.map(Double.init)
        // The system reports its actual lens transition and sensor-native factors. A single-camera
        // iPhone therefore shows only values it can produce, while dual- and triple-camera models
        // gain their available ultra-wide, telephoto, or high-resolution crop choices automatically.
        let candidates = ([minimum, oneTimesFactor] + switchOverFactors + nativeResolutionFactors)
            .filter { $0 >= minimum && $0 <= maximum }
            .sorted()

        var uniqueFactors: [Double] = []
        for factor in candidates where uniqueFactors.contains(where: { abs($0 - factor) < 0.05 }) == false {
            uniqueFactors.append(factor)
        }

        return uniqueFactors.map {
            RecordingCameraZoomOption(
                captureFactor: $0,
                displayFactor: $0 * displayMultiplier
            )
        }
    }

    private static func preferredBackCamera() -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        for deviceType in deviceTypes {
            if let camera = AVCaptureDevice.default(deviceType, for: .video, position: .back) {
                return camera
            }
        }
        return nil
    }

    private static func normalizedPower(_ decibels: Float) -> Double {
        let clampedDecibels = max(-60, min(0, decibels))
        return pow(10, Double(clampedDecibels) / 20)
    }

    private enum SessionError: Error {
        case noMicrophone
        case noCamera
        case configurationFailed
        case couldNotStart
    }
}

extension RecordingCaptureSessionCoordinator: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let result: RecordingPhotoCameraController.CaptureResult
        if error == nil, let data = photo.fileDataRepresentation() {
            result = .success(CapturedPhoto(data: data, preferredFileExtension: "jpeg"))
        } else {
            result = .failure
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            let completion = captureCompletion
            captureCompletion = nil
            DispatchQueue.main.async { completion?(result) }
        }
    }
}

struct RecordingAudioFile: Sendable {
    let url: URL
    let duration: TimeInterval
}

private final class RecordingAudioSampleWriter: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    let queue = DispatchQueue(label: "com.tysonpitcher.ListenHere.recordingAudioSamples")

    private var assetWriter: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var firstPresentationTime: CMTime?
    private var lastPresentationTime: CMTime?
    private var recordingStartedUptime: TimeInterval = 0
    private var lastSampleUptime: TimeInterval?
    private var recording = false

    var isRecording: Bool {
        queue.sync { recording }
    }

    var isReceivingSamples: Bool {
        queue.sync {
            guard recording else { return false }
            let mostRecentActivity = lastSampleUptime ?? recordingStartedUptime
            return ProcessInfo.processInfo.systemUptime - mostRecentActivity < 1
        }
    }

    func prepare(toWrite url: URL) throws {
        try queue.sync {
            guard recording == false else { throw WriterError.alreadyRecording }
            let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
            let input = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44_100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderBitRateKey: 128_000
                ]
            )
            input.expectsMediaDataInRealTime = true
            guard writer.canAdd(input) else { throw WriterError.configurationFailed }
            writer.add(input)
            guard writer.startWriting() else {
                throw writer.error ?? WriterError.couldNotStart
            }
            assetWriter = writer
            writerInput = input
            outputURL = url
            firstPresentationTime = nil
            lastPresentationTime = nil
            recordingStartedUptime = ProcessInfo.processInfo.systemUptime
            lastSampleUptime = nil
            recording = true
        }
    }

    func finish() async throws -> RecordingAudioFile {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                guard recording,
                      let writer = assetWriter,
                      let input = writerInput,
                      let url = outputURL,
                      let firstPresentationTime,
                      let lastPresentationTime else {
                    reset()
                    continuation.resume(throwing: WriterError.noAudioSamples)
                    return
                }

                recording = false
                input.markAsFinished()
                writer.finishWriting { [weak self] in
                    guard let self else {
                        continuation.resume(throwing: WriterError.couldNotFinish)
                        return
                    }
                    queue.async {
                        let duration = max(
                            0,
                            CMTimeGetSeconds(lastPresentationTime - firstPresentationTime)
                        )
                        let error = writer.error
                        reset()
                        if writer.status == .completed, error == nil {
                            continuation.resume(returning: RecordingAudioFile(url: url, duration: duration))
                        } else {
                            continuation.resume(throwing: error ?? WriterError.couldNotFinish)
                        }
                    }
                }
            }
        }
    }

    func cancel() async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                let url = outputURL
                recording = false
                assetWriter?.cancelWriting()
                reset()
                if let url {
                    try? FileManager.default.removeItem(at: url)
                }
                continuation.resume()
            }
        }
    }

    nonisolated func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        guard recording, let writer = assetWriter, let input = writerInput else { return }
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if firstPresentationTime == nil {
            writer.startSession(atSourceTime: presentationTime)
            firstPresentationTime = presentationTime
        }
        guard input.isReadyForMoreMediaData, input.append(sampleBuffer) else { return }
        lastSampleUptime = ProcessInfo.processInfo.systemUptime
        let sampleDuration = CMSampleBufferGetDuration(sampleBuffer)
        lastPresentationTime = sampleDuration.isValid
            ? presentationTime + sampleDuration
            : presentationTime
    }

    private func reset() {
        assetWriter = nil
        writerInput = nil
        outputURL = nil
        firstPresentationTime = nil
        lastPresentationTime = nil
        recordingStartedUptime = 0
        lastSampleUptime = nil
        recording = false
    }

    private enum WriterError: Error {
        case alreadyRecording
        case configurationFailed
        case couldNotStart
        case noAudioSamples
        case couldNotFinish
    }
}
