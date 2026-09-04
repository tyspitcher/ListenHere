// Loads active memories with canonical locations and groups nearby coordinates for map browsing.

import Foundation
import MapKit
import Observation

enum PlacesState: Equatable {
    case loading
    case loaded([PlaceSummary])
    case failed
}

@MainActor
@Observable
final class PlacesViewModel {
    private(set) var state: PlacesState = .loading

    private let repository: any MemoryRepository
    private let mediaReader: (any ManagedMediaReading)?
    private let locationNameBackfiller: (any MemoryLocationNameBackfilling)?
    private var visibleRegion: MKCoordinateRegion?
    private var managedPhotoURLs: [MemorySummary.ID: URL] = [:]
    private var locationNameBackfillTask: Task<Void, Never>?

    init(
        repository: any MemoryRepository,
        mediaReader: (any ManagedMediaReading)? = nil,
        locationNameBackfiller: (any MemoryLocationNameBackfilling)? = nil
    ) {
        self.repository = repository
        self.mediaReader = mediaReader
        self.locationNameBackfiller = locationNameBackfiller
    }

    var clusters: [PlaceCluster] {
        guard case .loaded(let places) = state else { return [] }
        return Self.cluster(places, in: visibleRegion)
    }

    func load() async {
        locationNameBackfillTask?.cancel()
        state = .loading
        do {
            let memories = try await repository.fetchActiveMemories()
            try Task.checkCancellation()
            managedPhotoURLs = resolveManagedPhotoURLs(in: memories)
            state = .loaded(Self.group(memories))
            startLocationNameBackfill(for: memories)
        } catch is CancellationError {
            return
        } catch {
            state = .failed
        }
    }

    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        guard visibleRegion.map({ Self.regionsDiffer($0, region) }) ?? true else { return }
        visibleRegion = region
    }

    func managedPhotoURL(for memory: MemorySummary) -> URL? {
        managedPhotoURLs[memory.id]
    }

    private static func group(_ memories: [MemorySummary]) -> [PlaceSummary] {
        memories.compactMap { memory -> PlaceSummary? in
            guard let location = memory.location else { return nil }
            return PlaceSummary(
                id: memory.id.uuidString,
                location: location,
                memories: [memory]
            )
        }
        .sorted { $0.memories[0].capturedAt > $1.memories[0].capturedAt }
    }

    private static func cluster(
        _ places: [PlaceSummary],
        in region: MKCoordinateRegion?
    ) -> [PlaceCluster] {
        guard let region else {
            return places.map { place in
                PlaceCluster(id: place.id, location: place.location, memories: place.memories)
            }
        }

        // Each grid cell is about 8% of the visible map. As the MapKit camera zooms out, that
        // cell grows and nearby memories collapse into a single tappable cluster; zooming in
        // naturally separates them again without changing saved memory locations.
        let latitudeStep = max(region.span.latitudeDelta * 0.08, 0.000_01)
        let longitudeStep = max(region.span.longitudeDelta * 0.08, 0.000_01)
        let grouped = Dictionary(grouping: places) { place in
            let latitudeCell = Int(floor(place.location.latitude / latitudeStep))
            let longitudeCell = Int(floor(place.location.longitude / longitudeStep))
            return "\(latitudeCell)-\(longitudeCell)"
        }

        return grouped.values.map { places in
            let memories = places.flatMap(\.memories).sorted { $0.capturedAt > $1.capturedAt }
            let latitude = places.map(\.location.latitude).reduce(0, +) / Double(places.count)
            let longitude = places.map(\.location.longitude).reduce(0, +) / Double(places.count)
            let names = Set(places.compactMap { $0.location.name }.filter { $0.isEmpty == false })
            let locationName = names.count == 1 ? names.first : nil
            let location = MemoryLocation(
                latitude: latitude,
                longitude: longitude,
                name: locationName,
                source: .manualPin
            )
            return PlaceCluster(
                id: memories.map(\.id.uuidString).sorted().joined(separator: "-"),
                location: location,
                memories: memories
            )
        }
        .sorted { $0.memories[0].capturedAt > $1.memories[0].capturedAt }
    }

    static func filter(_ clusters: [PlaceCluster], matching query: String) -> [PlaceCluster] {
        clusters.compactMap { cluster in
            if cluster.title.localizedCaseInsensitiveContains(query) {
                return cluster
            }

            let matchingMemories = cluster.memories.filter { memory in
                memory.title.localizedCaseInsensitiveContains(query)
                    || memory.caption?.localizedCaseInsensitiveContains(query) == true
                    || memory.location?.displayName.localizedCaseInsensitiveContains(query) == true
            }
            guard matchingMemories.isEmpty == false else { return nil }
            return PlaceCluster(
                id: cluster.id,
                location: cluster.location,
                memories: matchingMemories
            )
        }
    }

    private static func regionsDiffer(
        _ lhs: MKCoordinateRegion,
        _ rhs: MKCoordinateRegion
    ) -> Bool {
        let latitudeTolerance = max(abs(rhs.span.latitudeDelta) * 0.000_1, 0.000_001)
        let longitudeTolerance = max(abs(rhs.span.longitudeDelta) * 0.000_1, 0.000_001)

        return abs(lhs.center.latitude - rhs.center.latitude) > latitudeTolerance
            || abs(lhs.center.longitude - rhs.center.longitude) > longitudeTolerance
            || abs(lhs.span.latitudeDelta - rhs.span.latitudeDelta) > latitudeTolerance
            || abs(lhs.span.longitudeDelta - rhs.span.longitudeDelta) > longitudeTolerance
    }

    private func resolveManagedPhotoURLs(in memories: [MemorySummary]) -> [MemorySummary.ID: URL] {
        guard let mediaReader else { return [:] }

        return Dictionary(
            uniqueKeysWithValues: memories.compactMap { memory in
                guard case .managedFile(let filename) = memory.thumbnail,
                      let url = try? mediaReader.fileURL(for: filename) else {
                    return nil
                }
                return (memory.id, url)
            }
        )
    }

    private func startLocationNameBackfill(for memories: [MemorySummary]) {
        guard let locationNameBackfiller,
              memories.contains(where: { $0.location?.normalizedName == nil }) else {
            return
        }

        let expectedIDs = memories.map(\.id)
        locationNameBackfillTask = Task { [weak self] in
            let namedMemories = await locationNameBackfiller.resolveMissingNames(in: memories)
            guard Task.isCancelled == false,
                  let self,
                  case .loaded(let currentPlaces) = state,
                  currentPlaces.flatMap(\.memories).map(\.id).sorted(by: { $0.uuidString < $1.uuidString })
                    == expectedIDs.sorted(by: { $0.uuidString < $1.uuidString }) else {
                return
            }
            state = .loaded(Self.group(namedMemories))
        }
    }
}
