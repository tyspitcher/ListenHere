import Testing
@testable import ListenHere

@MainActor
struct CameraCaptureViewModelTests {
    @Test("An authorized camera can be presented without requesting again")
    func authorizedCamera() async {
        let service = CameraAuthorizationServiceStub(status: .authorized)
        let viewModel = CameraCaptureViewModel(authorizationService: service)

        #expect(await viewModel.prepareCamera())
        #expect(service.requestCount == 0)
        #expect(viewModel.failure == nil)
    }

    @Test("First-use authorization presents the camera when granted")
    func firstUseGrant() async {
        let service = CameraAuthorizationServiceStub(status: .notDetermined, grantsAccess: true)
        let viewModel = CameraCaptureViewModel(authorizationService: service)

        #expect(await viewModel.prepareCamera())
        #expect(service.requestCount == 1)
    }

    @Test(arguments: [
        (CameraAuthorizationStatus.denied, CameraCaptureFailure.denied),
        (.restricted, .restricted),
        (.unavailable, .unavailable),
    ])
    func unavailableStatesShowActionableFailures(
        status: CameraAuthorizationStatus,
        expectedFailure: CameraCaptureFailure
    ) async {
        let viewModel = CameraCaptureViewModel(
            authorizationService: CameraAuthorizationServiceStub(status: status)
        )

        #expect(await viewModel.prepareCamera() == false)
        #expect(viewModel.failure == expectedFailure)
    }

    @Test("Denying the first authorization request reports denial")
    func firstUseDenial() async {
        let viewModel = CameraCaptureViewModel(
            authorizationService: CameraAuthorizationServiceStub(
                status: .notDetermined,
                grantsAccess: false
            )
        )

        #expect(await viewModel.prepareCamera() == false)
        #expect(viewModel.failure == .denied)
    }
}

@MainActor
private final class CameraAuthorizationServiceStub: CameraAuthorizationServicing {
    private let status: CameraAuthorizationStatus
    private let grantsAccess: Bool
    private(set) var requestCount = 0

    init(status: CameraAuthorizationStatus, grantsAccess: Bool = false) {
        self.status = status
        self.grantsAccess = grantsAccess
    }

    func authorizationStatus() -> CameraAuthorizationStatus { status }

    func requestAccess() async -> Bool {
        requestCount += 1
        return grantsAccess
    }
}
