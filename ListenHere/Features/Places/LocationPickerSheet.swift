// Lets a person select a captured location suggestion, remove it, or place an explicit MapKit pin.

import CoreLocation
import MapKit
import SwiftUI

@MainActor
struct LocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let applySelection: (MemoryLocation?) -> Void
    @State private var viewModel: LocationPickerViewModel
    @State private var isApplyingSelection = false

    init(
        viewModel: LocationPickerViewModel,
        applySelection: @escaping (MemoryLocation?) -> Void
    ) {
        self.applySelection = applySelection
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                if let selection = viewModel.selection {
                    Section("Selected Location") {
                        LocationDescriptionView(location: selection)
                    }
                }

                if viewModel.candidates.isEmpty == false {
                    Section {
                        ForEach(viewModel.candidates) { candidate in
                            Button { viewModel.selectCandidate(candidate.location) } label: {
                                LocationCandidateRow(
                                    location: candidate.location,
                                    isSelected: viewModel.isSelected(candidate.location)
                                )
                            }
                            .foregroundStyle(.primary)
                        }
                    } header: {
                        Text("Suggested Locations")
                    } footer: {
                        Text("Suggestions are optional. Choose one or set a pin yourself.")
                    }
                }

                Section {
                    NavigationLink("Set Location on Map") {
                        LocationPinEditor(
                            viewModel: viewModel
                        )
                    }

                    if viewModel.selection != nil {
                        Button("Remove Location", role: .destructive) {
                            viewModel.removeLocation()
                        }
                    }
                }
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        applyAndDismiss()
                    }
                    .disabled(isApplyingSelection)
                }
            }
        }
        .task { await viewModel.loadLocationNames() }
    }

    private func applyAndDismiss() {
        isApplyingSelection = true
        Task {
            let selection = await viewModel.finalizedSelection()
            applySelection(selection)
            dismiss()
        }
    }
}

private struct LocationCandidateRow: View {
    let location: MemoryLocation
    let isSelected: Bool

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.displayName)
                    Text(location.coordinateDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text(location.source.displayName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } icon: {
                Image(systemName: "location")
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct LocationDescriptionView: View {
    let location: MemoryLocation

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(location.displayName)
                Text(location.coordinateDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: "location")
        }
        .accessibilityElement(children: .combine)
    }
}

@MainActor
private struct LocationPinEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var position: MapCameraPosition
    @State private var shouldCenterOnCurrentLocation: Bool
    @State private var mapPresentation: MapPresentation = .explore
    @State private var isApplyingSelection = false
    @State private var didApplyPin = false
    private let viewModel: LocationPickerViewModel
    private let originalSelection: MemoryLocation?

    init(viewModel: LocationPickerViewModel) {
        self.viewModel = viewModel
        originalSelection = viewModel.selection
        _position = State(initialValue: Self.initialPosition(for: viewModel.selection))
        _shouldCenterOnCurrentLocation = State(initialValue: viewModel.selection == nil)
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                UserAnnotation()

                if let selection = viewModel.selection {
                    Marker(selection.displayName, coordinate: coordinate(for: selection))
                }
            }
            .mapStyle(mapPresentation.mapStyle)
            // MapKit owns the camera and map interaction. Its user-location camera requests a
            // one-time, when-in-use location through Core Location; the selected value remains a
            // framework-neutral MemoryLocation for the rest of the app.
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                viewModel.selectManualPin(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                shouldCenterOnCurrentLocation = false
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let selection = viewModel.selection {
                HStack(spacing: 12) {
                    LocationDescriptionView(location: selection)
                    Spacer(minLength: 8)
                    if viewModel.isResolvingSelection {
                        ProgressView()
                            .accessibilityLabel("Finding place name")
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle("Drop a Pin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.restoreSelection(originalSelection)
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Use This Pin") {
                    applyPinAndDismiss()
                }
                .disabled(viewModel.selection == nil || isApplyingSelection)
            }
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
        .task {
            await viewModel.loadCurrentLocation()
        }
        .onChange(of: viewModel.currentLocation) { _, location in
            guard shouldCenterOnCurrentLocation, let location else { return }
            position = .region(Self.region(around: location))
        }
        .onDisappear {
            if didApplyPin == false {
                viewModel.restoreSelection(originalSelection)
            }
        }
        .accessibilityHint("Tap the map to place a pin for this memory.")
    }

    private func coordinate(for location: MemoryLocation) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }

    private func applyPinAndDismiss() {
        isApplyingSelection = true
        Task {
            guard await viewModel.finalizedSelection() != nil else {
                isApplyingSelection = false
                return
            }
            didApplyPin = true
            dismiss()
        }
    }

    private static func initialPosition(for location: MemoryLocation?) -> MapCameraPosition {
        if let location {
            return .region(region(around: location))
        }

        return .userLocation(
            followsHeading: false,
            fallback: .region(region(around: nil))
        )
    }

    private static func region(around location: MemoryLocation?) -> MKCoordinateRegion {
        let center = if let location {
            CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        } else {
            CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795)
        }
        return MKCoordinateRegion(center: center, latitudinalMeters: 15_000, longitudinalMeters: 15_000)
    }
}
