// Renders the searchable map of canonical memory locations and opens a filtered place list.

import CoreLocation
import MapKit
import SwiftUI

struct PlacesView: View {
    @State private var viewModel: PlacesViewModel
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCluster: PlaceCluster?
    @State private var searchText = ""
    @State private var mapPresentation: MapPresentation = .explore

    let openMemory: (MemorySummary.ID) -> Void

    init(viewModel: PlacesViewModel, openMemory: @escaping (MemorySummary.ID) -> Void) {
        _viewModel = State(wrappedValue: viewModel)
        self.openMemory = openMemory
    }

    var body: some View {
        content
        .navigationTitle("Places")
        .searchable(text: $searchText, prompt: "Search places and memories")
        .onChange(of: searchText) { _, _ in
            updateCameraForSearch()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Map Style", selection: $mapPresentation) {
                        ForEach(MapPresentation.allCases) { presentation in
                            Label(presentation.title, systemImage: presentation.symbolName)
                                .tag(presentation)
                        }
                    }
                } label: {
                    Image(systemName: mapPresentation.symbolName)
                }
                .accessibilityLabel("Map Style")
                .accessibilityValue(mapPresentation.title)
            }
        }
        .task { await loadPlaces() }
        .sheet(item: $selectedCluster) { cluster in
            PlaceMemoryList(
                cluster: cluster,
                managedPhotoURL: viewModel.managedPhotoURL(for:),
                openMemory: openMemory
            )
        }
        .appScreenBackground()
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("Loading Places")
        case .loaded(let places) where places.isEmpty:
            ContentUnavailableView(
                "No Places Yet",
                systemImage: "map",
                description: Text("Places appear after memories are saved with location information.")
            )
        case .loaded:
            map
        case .failed:
            ContentUnavailableView {
                Label("Couldn’t Load Places", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Try again to see memories on the map.")
            } actions: {
                Button("Try Again") {
                    Task { await loadPlaces() }
                }
            }
        }
    }

    private var map: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position) {
                ForEach(filteredClusters) { cluster in
                    Annotation(cluster.title, coordinate: coordinate(for: cluster.location)) {
                        Button {
                            selectedCluster = cluster
                        } label: {
                            PlaceClusterMarker(count: cluster.memories.count)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(cluster.title)
                        .accessibilityValue(cluster.subtitle)
                        .accessibilityHint("Shows these memories in a list.")
                    }
                }
            }
            .mapStyle(mapPresentation.mapStyle)
            // MapKit reports the visible region after each completed pan or zoom. The view model uses
            // that transient camera state to form display-only clusters while saved memory locations
            // remain independent, precise domain values.
            .onMapCameraChange(frequency: .onEnd) { context in
                viewModel.updateVisibleRegion(context.region)
            }

            if isSearching {
                Text(searchResultDescription)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding()
                    .accessibilityLabel("Places search")
                    .accessibilityValue(searchResultDescription)
            }
        }
    }

    private var filteredClusters: [PlaceCluster] {
        guard let query = normalizedSearchText else { return viewModel.clusters }
        return PlacesViewModel.filter(viewModel.clusters, matching: query)
    }

    private var normalizedSearchText: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var isSearching: Bool {
        normalizedSearchText != nil
    }

    private var searchResultDescription: String {
        let memoryCount = filteredClusters.reduce(0) { $0 + $1.memories.count }
        guard memoryCount > 0 else { return "No matching places or memories" }
        let memoryNoun = memoryCount == 1 ? "memory" : "memories"
        let placeNoun = filteredClusters.count == 1 ? "place" : "places"
        return "\(memoryCount) \(memoryNoun) in \(filteredClusters.count) \(placeNoun)"
    }

    private func coordinate(for location: MemoryLocation) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }

    private func loadPlaces() async {
        await viewModel.load()
        guard case .loaded(let places) = viewModel.state,
              let initialRegion = initialRegion(containing: places) else {
            return
        }

        // MapKit's automatic camera refits whenever annotations change. Clustering also changes
        // annotations when the camera changes, so leaving both behaviors active creates a feedback
        // loop. Establish one explicit camera region after loading, then let gestures own it.
        position = .region(initialRegion)
        viewModel.updateVisibleRegion(initialRegion)
        updateCameraForSearch()
    }

    private func updateCameraForSearch() {
        guard case .loaded(let places) = viewModel.state else { return }
        let locations = isSearching ? filteredClusters.map(\.location) : places.map(\.location)
        guard let region = region(containing: locations) else { return }
        position = .region(region)
    }

    private func initialRegion(containing places: [PlaceSummary]) -> MKCoordinateRegion? {
        region(containing: places.map(\.location))
    }

    private func region(containing locations: [MemoryLocation]) -> MKCoordinateRegion? {
        guard let first = locations.first else { return nil }

        let latitudes = locations.map(\.latitude)
        let longitudes = locations.map(\.longitude)
        let minimumLatitude = latitudes.min() ?? first.latitude
        let maximumLatitude = latitudes.max() ?? first.latitude
        let minimumLongitude = longitudes.min() ?? first.longitude
        let maximumLongitude = longitudes.max() ?? first.longitude

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minimumLatitude + maximumLatitude) / 2,
                longitude: (minimumLongitude + maximumLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max((maximumLatitude - minimumLatitude) * 1.35, 0.02),
                longitudeDelta: max((maximumLongitude - minimumLongitude) * 1.35, 0.02)
            )
        )
    }
}

private struct PlaceClusterMarker: View {
    let count: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(.tint)
                .frame(width: count > 1 ? 42 : 30, height: count > 1 ? 42 : 30)
            if count > 1 {
                Text(count, format: .number)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "mappin")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .shadow(radius: 2, y: 1)
    }
}

private struct PlaceMemoryList: View {
    @Environment(\.dismiss) private var dismiss

    let cluster: PlaceCluster
    let managedPhotoURL: (MemorySummary) -> URL?
    let openMemory: (MemorySummary.ID) -> Void

    var body: some View {
        NavigationStack {
            List(cluster.memories) { memory in
                Button {
                    dismiss()
                    openMemory(memory.id)
                } label: {
                    PlaceMemoryRow(memory: memory, managedPhotoURL: managedPhotoURL(memory))
                }
            }
            .navigationTitle(cluster.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct PlaceMemoryRow: View {
    let memory: MemorySummary
    let managedPhotoURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(memory.title)
                    .foregroundStyle(.primary)
                Text(memory.capturedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch memory.thumbnail {
        case .previewAsset(let name):
            Image(name)
                .resizable()
                .scaledToFill()
        case .managedFile:
            if let managedPhotoURL {
                ManagedPhotoImageView(photoURL: managedPhotoURL, contentMode: .fill, maximumPixelSize: 160)
            } else {
                placeholderThumbnail
            }
        case nil:
            placeholderThumbnail
        }
    }

    private var placeholderThumbnail: some View {
        Image(systemName: memory.hasAudio ? "waveform" : "photo")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary)
    }
}
