// Bridges camera availability and just-in-time authorization into a testable domain-facing status.

import AVFoundation
import UIKit

@MainActor
final class AVFoundationCameraAuthorizationService: CameraAuthorizationServicing {
    func authorizationStatus() -> CameraAuthorizationStatus {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return .unavailable }

        // AVCaptureDevice owns camera authorization even though UIImagePickerController renders
        // the system camera. Keeping permission here lets the composer handle denial explicitly.
        return switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            .notDetermined
        case .authorized:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        @unknown default:
            .restricted
        }
    }

    func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
