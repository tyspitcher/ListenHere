// Coordinates optional location suggestions, manual pins, current location, and reverse geocoding.

import Foundation
import Observation

typealias LocationPickerViewModelFactory = (
    [MemoryLocationCandidate],
    MemoryLocation?
) -> LocationPickerViewModel

@MainActor
@Observable
final class LocationPickerViewModel {
    private let currentLocationProvider: any CurrentLocationProviding
    private let locationNameResolver: any LocationNameResolving
    private var selectionResolutionTask: Task<Void, Never>?

    private(set) var candidates: [MemoryLocationCandidate]
    private(set) var selection: MemoryLocation?
    private(set) var currentLocation: MemoryLocation?
    private(set) var isResolvingSelection = false

    init(
        candidates: [MemoryLocationCandidate],
        initialLocation: MemoryLocation?,
        currentLocationProvider: any CurrentLocationProviding,
        locationNameResolver: any LocationNameResolving
    ) {
        self.candidates = candidates
        selection = initialLocation
        self.currentLocationProvider = currentLocationProvider
        self.locationNameResolver = locationNameResolver
    }

    func loadLocationNames() async {
        for candidate in candidates where candidate.location.normalizedName == nil {
            guard Task.isCancelled == false else { return }
            let resolvedLocation = await resolveName(for: candidate.location)
            updateCandidate(resolvedLocation)
            updateSelectionIfMatching(resolvedLocation)
        }

        guard let selection, selection.normalizedName == nil else { return }
        let resolvedSelection = await resolveName(for: selection)
        updateSelectionIfMatching(resolvedSelection)
    }

    func loadCurrentLocation() async {
        do {
            currentLocation = try await currentLocationProvider.requestCurrentLocation().location
        } catch {
            // Location is optional. The map's fallback region remains usable when permission is
            // denied or a temporary location fix cannot be obtained.
        }
    }

    func selectCandidate(_ location: MemoryLocation) {
        selection = location
        beginResolvingSelectionIfNeeded()
    }

    func selectManualPin(latitude: Double, longitude: Double) {
        selection = MemoryLocation(
            latitude: latitude,
            longitude: longitude,
            source: .manualPin
        )
        beginResolvingSelectionIfNeeded()
    }

    func removeLocation() {
        selectionResolutionTask?.cancel()
        selectionResolutionTask = nil
        isResolvingSelection = false
        selection = nil
    }

    func restoreSelection(_ location: MemoryLocation?) {
        selectionResolutionTask?.cancel()
        selectionResolutionTask = nil
        isResolvingSelection = false
        selection = location
    }

    func isSelected(_ location: MemoryLocation) -> Bool {
        guard let selection else { return false }
        return representsSamePlace(selection, location)
    }

    func finalizedSelection() async -> MemoryLocation? {
        await selectionResolutionTask?.value
        guard let selection else { return nil }
        guard selection.normalizedName == nil else { return selection }

        isResolvingSelection = true
        let requestedLocation = selection
        let resolvedLocation = await resolveName(for: requestedLocation)
        guard let currentSelection = self.selection,
              representsSamePlace(currentSelection, requestedLocation) else {
            isResolvingSelection = false
            return self.selection
        }
        self.selection = resolvedLocation
        updateCandidate(resolvedLocation)
        isResolvingSelection = false
        return resolvedLocation
    }

    private func beginResolvingSelectionIfNeeded() {
        selectionResolutionTask?.cancel()
        guard let selection, selection.normalizedName == nil else {
            isResolvingSelection = false
            selectionResolutionTask = nil
            return
        }

        let requestedLocation = selection
        isResolvingSelection = true
        selectionResolutionTask = Task { [weak self] in
            guard let self else { return }
            let resolvedLocation = await self.resolveName(for: requestedLocation)
            guard Task.isCancelled == false,
                  let currentSelection = self.selection,
                  self.representsSamePlace(currentSelection, requestedLocation) else {
                return
            }
            self.selection = resolvedLocation
            self.updateCandidate(resolvedLocation)
            self.isResolvingSelection = false
            self.selectionResolutionTask = nil
        }
    }

    private func resolveName(for location: MemoryLocation) async -> MemoryLocation {
        guard location.normalizedName == nil else { return location }
        do {
            guard let name = try await locationNameResolver.name(for: location) else {
                return location
            }
            var resolvedLocation = location
            resolvedLocation.name = name
            return resolvedLocation
        } catch {
            // Reverse geocoding can be unavailable offline. Coordinates remain a valid, editable
            // location and are retained as the secondary description.
            return location
        }
    }

    private func updateCandidate(_ location: MemoryLocation) {
        guard let index = candidates.firstIndex(where: {
            representsSamePlace($0.location, location)
        }) else { return }
        candidates[index] = MemoryLocationCandidate(location: location)
    }

    private func updateSelectionIfMatching(_ location: MemoryLocation) {
        guard let selection, representsSamePlace(selection, location) else { return }
        self.selection = location
    }

    private func representsSamePlace(_ lhs: MemoryLocation, _ rhs: MemoryLocation) -> Bool {
        lhs.latitude == rhs.latitude
            && lhs.longitude == rhs.longitude
            && lhs.source == rhs.source
    }
}
