import Testing
@testable import ListenHere

struct LocationPickerViewModelTests {
    @Test("Loads the one-time current location for the map camera")
    @MainActor
    func loadCurrentLocation() async {
        let expected = MemoryLocation(
            latitude: 40.7608,
            longitude: -111.8910,
            source: .deviceCapture
        )
        let viewModel = makeViewModel(locationResult: .success(expected))

        await viewModel.loadCurrentLocation()

        #expect(viewModel.currentLocation == expected)
    }

    @Test("Unavailable location leaves the map camera unchanged")
    @MainActor
    func unavailableLocation() async {
        let viewModel = makeViewModel(
            locationResult: .failure(CurrentLocationError.unavailable)
        )

        await viewModel.loadCurrentLocation()

        #expect(viewModel.currentLocation == nil)
    }

    @Test("Reverse geocoding names suggestions and the selected location")
    @MainActor
    func resolvesSuggestedLocationName() async {
        let location = MemoryLocation(
            latitude: 37.2982,
            longitude: -113.0263,
            source: .photoMetadata
        )
        let viewModel = makeViewModel(
            candidates: [MemoryLocationCandidate(location: location)],
            initialLocation: location,
            resolvedName: "Zion National Park"
        )

        await viewModel.loadLocationNames()

        #expect(viewModel.candidates.first?.location.name == "Zion National Park")
        #expect(viewModel.selection?.name == "Zion National Park")
    }

    @Test("Finalizing a manual pin retains its resolved area name")
    @MainActor
    func finalizesManualPinName() async {
        let viewModel = makeViewModel(resolvedName: "West Jordan, UT")

        viewModel.selectManualPin(latitude: 40.6097, longitude: -111.9391)
        let selection = await viewModel.finalizedSelection()

        #expect(selection?.name == "West Jordan, UT")
        #expect(selection?.coordinateDescription == "40.6097°, -111.9391°")
    }

    @MainActor
    private func makeViewModel(
        candidates: [MemoryLocationCandidate] = [],
        initialLocation: MemoryLocation? = nil,
        locationResult: Result<MemoryLocation, Error> = .failure(CurrentLocationError.unavailable),
        resolvedName: String? = nil
    ) -> LocationPickerViewModel {
        LocationPickerViewModel(
            candidates: candidates,
            initialLocation: initialLocation,
            currentLocationProvider: LocationProviderStub(result: locationResult),
            locationNameResolver: LocationNameResolverStub(name: resolvedName)
        )
    }
}

@MainActor
private final class LocationProviderStub: CurrentLocationProviding {
    let result: Result<MemoryLocation, Error>

    init(result: Result<MemoryLocation, Error>) {
        self.result = result
    }

    func requestCurrentLocation() async throws -> MemoryLocationCandidate {
        MemoryLocationCandidate(location: try result.get())
    }
}

@MainActor
private final class LocationNameResolverStub: LocationNameResolving {
    let name: String?

    init(name: String?) {
        self.name = name
    }

    func name(for _: MemoryLocation) async throws -> String? {
        name
    }
}
