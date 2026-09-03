// Coordinates camera availability and authorization before the system camera is presented.

import Observation

enum CameraCaptureFailure: Equatable {
    case denied
    case restricted
    case unavailable

    var message: String {
        switch self {
        case .denied:
            "Camera access is turned off. Enable it in Settings to take a photo."
        case .restricted:
            "Camera access is restricted on this device."
        case .unavailable:
            "A camera isn’t available on this device. You can choose a photo from the library instead."
        }
    }

    var canOpenSettings: Bool { self == .denied }
}

@MainActor
@Observable
final class CameraCaptureViewModel {
    private(set) var failure: CameraCaptureFailure?
    private(set) var isRequestingAccess = false

    private let authorizationService: any CameraAuthorizationServicing

    init(authorizationService: any CameraAuthorizationServicing) {
        self.authorizationService = authorizationService
    }

    func prepareCamera() async -> Bool {
        failure = nil

        switch authorizationService.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            isRequestingAccess = true
            let granted = await authorizationService.requestAccess()
            isRequestingAccess = false
            if granted { return true }
            failure = .denied
        case .denied:
            failure = .denied
        case .restricted:
            failure = .restricted
        case .unavailable:
            failure = .unavailable
        }
        return false
    }

    func acknowledgeFailure() {
        failure = nil
    }
}
