// Defines camera availability and permission without exposing AVFoundation to SwiftUI.

enum CameraAuthorizationStatus: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable
}

@MainActor
protocol CameraAuthorizationServicing: AnyObject {
    func authorizationStatus() -> CameraAuthorizationStatus
    func requestAccess() async -> Bool
}
