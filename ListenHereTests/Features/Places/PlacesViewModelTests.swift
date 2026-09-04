import Foundation
import MapKit
import Observation
import Synchronization
import Testing
@testable import ListenHere

struct PlacesViewModelTests {
    @Test("Nearby memories cluster when the map is zoomed out")
    @MainActor
    func loadGroupsLocations() async {
        let location = MemoryLocation(latitude: 40.7608, longitude: -111.8910, source: .manualPin)
        let repository = PlacesMemoryRepositoryStub(result: .success([
            memory(title: "Morning Walk", location: location, date: 2),
            memory(title: "Coffee", location: location, date: 1),
            memory(title: "No Location", location: nil, date: 3),
        ]))
        let viewModel = PlacesViewModel(repository: repository)

        await viewModel.load()

        guard case .loaded(let places) = viewModel.state else {
            Issue.record("Expected loaded places")
            return
        }
        #expect(places.count == 2)

        viewModel.updateVisibleRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.7608, longitude: -111.8910),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        )

        #expect(viewModel.clusters.count == 1)
        #expect(viewModel.clusters[0].memories.map(\.title) == ["Morning Walk", "Coffee"])
    }

    @Test("Zooming in separates distinct nearby memory pins")
    @MainActor
    func zoomingInSeparatesClusters() async {
        let first = MemoryLocation(latitude: 40.7608, longitude: -111.8910, source: .manualPin)
        let second = MemoryLocation(latitude: 40.7620, longitude: -111.8895, source: .manualPin)
        let viewModel = PlacesViewModel(repository: PlacesMemoryRepositoryStub(result: .success([
            memory(title: "Morning Walk", location: first, date: 2),
            memory(title: "Coffee", location: second, date: 1),
        ])))

        await viewModel.load()
        viewModel.updateVisibleRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.7608, longitude: -111.8910),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )

        #expect(viewModel.clusters.count == 2)
    }

    @Test("Equivalent camera callbacks do not invalidate map clusters")
    @MainActor
    func equivalentCameraCallbacksAreIgnored() async {
        let location = MemoryLocation(latitude: 40.7608, longitude: -111.8910, source: .manualPin)
        let viewModel = PlacesViewModel(repository: PlacesMemoryRepositoryStub(result: .success([
            memory(title: "Morning Walk", location: location, date: 1),
        ])))
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.7608, longitude: -111.8910),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )

        await viewModel.load()
        viewModel.updateVisibleRegion(region)

        let clustersWereInvalidated = Mutex(false)
        withObservationTracking {
            _ = viewModel.clusters
        } onChange: {
            clustersWereInvalidated.withLock { $0 = true }
        }

        viewModel.updateVisibleRegion(region)

        #expect(clustersWereInvalidated.withLock { $0 } == false)
    }

    @Test("Search narrows a place cluster to memories with matching titles")
    @MainActor
    func searchFiltersClusterMemoriesByTitle() {
        let location = MemoryLocation(latitude: 40.7608, longitude: -111.8910, source: .manualPin)
        let matchingMemory = memory(title: "Morning Walk", location: location, date: 2)
        let otherMemory = memory(title: "Coffee", location: location, date: 1)
        let cluster = PlaceCluster(
            id: "neighborhood",
            location: location,
            memories: [matchingMemory, otherMemory]
        )

        let results = PlacesViewModel.filter([cluster], matching: "walk")

        #expect(results.count == 1)
        #expect(results[0].memories == [matchingMemory])
    }

    @Test("Repository failure produces a retryable places failure")
    @MainActor
    func loadFailure() async {
        let viewModel = PlacesViewModel(repository: PlacesMemoryRepositoryStub(result: .failure(PlacesTestError.failed)))

        await viewModel.load()

        #expect(viewModel.state == .failed)
    }

    private func memory(title: String, location: MemoryLocation?, date: TimeInterval) -> MemorySummary {
        MemorySummary(
            id: UUID(),
            title: title,
            caption: nil,
            capturedAt: Date(timeIntervalSince1970: date),
            thumbnail: nil,
            hasAudio: false,
            audioDurationSeconds: nil,
            locationName: location?.name,
            location: location,
            journalNames: []
        )
    }
}

@MainActor
private final class PlacesMemoryRepositoryStub: MemoryRepository {
    let result: Result<[MemorySummary], Error>

    init(result: Result<[MemorySummary], Error>) {
        self.result = result
    }

    func fetchActiveMemories() async throws -> [MemorySummary] { try result.get() }
    func fetchActiveMemories(journalID: UUID) async throws -> [MemorySummary] { try result.get() }
    func fetchActiveMemory(id: UUID) async throws -> MemorySummary? { try result.get().first { $0.id == id } }
    func createMemory(from draft: MemoryDraft, origin: MemoryCreationOrigin) throws -> Memory { throw PlacesTestError.failed }
    func updateJournalAssignments(memoryID: UUID, journalIDs: Set<UUID>) throws { throw PlacesTestError.failed }
    func moveToRecentlyDeleted(memoryID: UUID, at date: Date) throws { throw PlacesTestError.failed }
}

private enum PlacesTestError: Error {
    case failed
}
