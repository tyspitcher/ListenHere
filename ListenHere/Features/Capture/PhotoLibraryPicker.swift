// Adapts PhotosPicker into a managed photo-data import while keeping Photos URLs out of domain state.

import Foundation
import PhotosUI
import SwiftUI

struct PhotoLibraryPicker: View {
    var title = "Choose from Library"
    let onPhotoDataSelected: (Data, String) -> Void
    let onImportFailure: () -> Void

    @State private var isPresented = false
    @State private var isImporting = false

    var body: some View {
        Group {
            if isImporting {
                ProgressView("Adding Photo")
            } else {
                Button {
                    isPresented = true
                } label: {
                    Label(title, systemImage: "photo.on.rectangle")
                }
            }
        }
        .managedPhotoLibraryPicker(
            isPresented: $isPresented,
            isImporting: $isImporting,
            onPhotoDataSelected: onPhotoDataSelected,
            onImportFailure: onImportFailure
        )
    }
}

extension View {
    func managedPhotoLibraryPicker(
        isPresented: Binding<Bool>,
        isImporting: Binding<Bool>,
        onPhotoDataSelected: @escaping (Data, String) -> Void,
        onImportFailure: @escaping () -> Void
    ) -> some View {
        modifier(
            ManagedPhotoLibraryPickerModifier(
                isPresented: isPresented,
                isImporting: isImporting,
                onPhotoDataSelected: onPhotoDataSelected,
                onImportFailure: onImportFailure
            )
        )
    }
}

private struct ManagedPhotoLibraryPickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var isImporting: Bool

    let onPhotoDataSelected: (Data, String) -> Void
    let onImportFailure: () -> Void

    @State private var selection: PhotosPickerItem?
    @State private var importTask: Task<Void, Never>?
    @State private var importGeneration = 0

    func body(content: Content) -> some View {
        content
            .photosPicker(
                isPresented: $isPresented,
                selection: $selection,
                matching: .images
            )
            .onChange(of: selection) { _, item in
                guard let item else { return }
                importPhoto(from: item)
            }
    }

    private func importPhoto(from item: PhotosPickerItem) {
        importTask?.cancel()
        importGeneration += 1
        let generation = importGeneration
        let fileExtension = item.supportedContentTypes.first?.preferredFilenameExtension ?? "heic"
        isImporting = true

        importTask = Task {
            // PhotosPickerItem grants temporary access to Photos content. This adapter reads the
            // selection while access is valid, then the caller stores a private managed copy.
            // Do not cancel this task from onDisappear: dismissing the system picker can make the
            // presenting SwiftUI view temporarily disappear before this transfer completes.
            defer {
                if importGeneration == generation {
                    isImporting = false
                    selection = nil
                }
            }

            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    onImportFailure()
                    return
                }
                try Task.checkCancellation()
                onPhotoDataSelected(data, fileExtension)
            } catch is CancellationError {
                return
            } catch {
                onImportFailure()
            }
        }
    }
}
