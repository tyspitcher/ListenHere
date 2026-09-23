// Owns the still-photo capture session used while ambient audio keeps recording.

import AVFoundation
import SwiftUI
import UIKit

enum RecordingCameraFlashMode: String, CaseIterable, Identifiable, Sendable {
    case off
    case auto
    case on

    var id: Self { self }

    var title: String {
        switch self {
        case .off: "Off"
        case .auto: "Auto"
        case .on: "On"
        }
    }

    var systemImage: String {
        switch self {
        case .off: "bolt.slash.fill"
        case .auto: "bolt.badge.a.fill"
        case .on: "bolt.fill"
        }
    }

    var avFoundationValue: AVCaptureDevice.FlashMode {
        switch self {
        case .off: .off
        case .auto: .auto
        case .on: .on
        }
    }
}

struct RecordingPhotoCameraCapabilities: Sendable {
    let maximumZoomFactor: Double
    let zoomOptions: [RecordingCameraZoomOption]
    let flashModes: [RecordingCameraFlashMode]
    let initialZoomFactor: Double

    var supportsFlash: Bool { flashModes.count > 1 }

    static let unavailable = RecordingPhotoCameraCapabilities(
        maximumZoomFactor: 1,
        zoomOptions: [RecordingCameraZoomOption(captureFactor: 1, displayFactor: 1)],
        flashModes: [.off],
        initialZoomFactor: 1
    )
}

struct RecordingCameraZoomOption: Identifiable, Sendable {
    let captureFactor: Double
    let displayFactor: Double

    var id: Double { captureFactor }

    var label: String {
        let precision = displayFactor.rounded() == displayFactor ? 0 : 1
        return "\(displayFactor.formatted(.number.precision(.fractionLength(precision))))×"
    }
}

struct RecordingPhotoCameraPreview: UIViewRepresentable {
    let camera: RecordingPhotoCameraController
    let onZoomChanged: (Double) -> Void

    func makeUIView(context _: Context) -> RecordingPhotoPreviewView {
        let view = RecordingPhotoPreviewView()
        view.previewLayer.session = camera.session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onFocusPoint = camera.focus
        view.onPinchZoom = { scale in
            camera.changeZoom(by: scale, completion: onZoomChanged)
        }
        return view
    }

    func updateUIView(_ view: RecordingPhotoPreviewView, context _: Context) {
        view.onFocusPoint = camera.focus
        view.onPinchZoom = { scale in
            camera.changeZoom(by: scale, completion: onZoomChanged)
        }
    }
}

final class RecordingPhotoCameraController {
    enum CaptureResult: Sendable {
        case success(CapturedPhoto)
        case failure
    }

    var session: AVCaptureSession { coordinator.session }

    private let coordinator: RecordingCaptureSessionCoordinator

    init(coordinator: RecordingCaptureSessionCoordinator) {
        self.coordinator = coordinator
    }

    func start(
        onReady: @escaping (RecordingPhotoCameraCapabilities) -> Void,
        onFailure: @escaping () -> Void
    ) {
        coordinator.startCamera(onReady: onReady, onFailure: onFailure)
    }

    func stop() {
        coordinator.stopCamera()
    }

    func capturePhoto(
        flashMode: RecordingCameraFlashMode,
        completion: @escaping (CaptureResult) -> Void
    ) {
        coordinator.capturePhoto(flashMode: flashMode, completion: completion)
    }

    func focus(at point: CGPoint) {
        coordinator.focus(at: point)
    }

    func setZoomFactor(_ factor: Double) {
        coordinator.setZoomFactor(factor)
    }

    func changeZoom(by scale: CGFloat, completion: @escaping (Double) -> Void) {
        coordinator.changeZoom(by: scale, completion: completion)
    }
}

final class RecordingPhotoPreviewView: UIView {
    var onFocusPoint: ((CGPoint) -> Void)?
    var onPinchZoom: ((CGFloat) -> Void)?

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focus)))
        addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(zoom)))
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func focus(_ gesture: UITapGestureRecognizer) {
        let viewPoint = gesture.location(in: self)
        onFocusPoint?(previewLayer.captureDevicePointConverted(fromLayerPoint: viewPoint))
        showFocusReticle(at: viewPoint)
    }

    @objc private func zoom(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.state == .changed else { return }
        onPinchZoom?(gesture.scale)
        gesture.scale = 1
    }

    private func showFocusReticle(at point: CGPoint) {
        let reticle = UIView(frame: CGRect(x: 0, y: 0, width: 72, height: 72))
        reticle.center = point
        reticle.layer.borderColor = UIColor.systemYellow.cgColor
        reticle.layer.borderWidth = 2
        reticle.layer.cornerRadius = 8
        reticle.alpha = 0
        addSubview(reticle)

        UIView.animate(withDuration: 0.15, animations: {
            reticle.alpha = 1
            reticle.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.5, options: []) {
                reticle.alpha = 0
            } completion: { _ in
                reticle.removeFromSuperview()
            }
        }
    }
}
