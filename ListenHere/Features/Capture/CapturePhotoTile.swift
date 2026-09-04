// Adds or previews the capture draft's single photo within the composer.

import SwiftUI

struct CapturePhotoTile: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let photoURL: URL?
    let hasPhoto: Bool
    let isEnabled: Bool
    let takePhoto: () -> Void
    let importPhoto: (Data, String) -> Void
    let reportImportFailure: () -> Void
    let removePhoto: () -> Void

    @State private var removalConfirmationIsPresented = false
    @State private var photoLibraryIsPresented = false
    @State private var photoLibraryIsImporting = false

    var body: some View {
        Group {
            if hasPhoto {
                photoPreview
            } else {
                addPhotoButton
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(palette.surface, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(palette.separator)
        }
        .managedPhotoLibraryPicker(
            isPresented: $photoLibraryIsPresented,
            isImporting: $photoLibraryIsImporting,
            onPhotoDataSelected: importPhoto,
            onImportFailure: reportImportFailure
        )
        .disabled(isEnabled == false)
    }

    private var palette: AppPalette {
        theme.palette(for: colorScheme)
    }

    private var addPhotoButton: some View {
        Group {
            if photoLibraryIsImporting {
                ProgressView("Adding Photo")
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Menu {
                    Button("Take Photo", systemImage: "camera", action: takePhoto)
                    Button("Choose from Library", systemImage: "photo.on.rectangle") {
                        photoLibraryIsPresented = true
                    }
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.largeTitle)
                        Text("Add Photo")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.accent)
                .accessibilityHint("Choose the camera or Photo Library.")
            }
        }
    }

    private var photoPreview: some View {
        ManagedPhotoImageView(photoURL: photoURL, contentMode: .fill)
            .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 220)
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Added photo")
            .overlay(alignment: .topTrailing) {
                Button("Remove Photo", systemImage: "trash", action: presentRemovalConfirmation)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(palette.destructive)
                    .frame(minWidth: 44, minHeight: 44)
                    .padding(8)
                    .confirmationDialog(
                        "Remove This Photo?",
                        isPresented: $removalConfirmationIsPresented,
                        titleVisibility: .visible
                    ) {
                        Button("Remove Photo", role: .destructive, action: removePhoto)
                        Button("Keep Photo", role: .cancel) {}
                    } message: {
                        Text("The photo will be removed from this unsaved memory.")
                    }
            }
            .clipShape(.rect(cornerRadius: 20))
    }

    private func presentRemovalConfirmation() {
        removalConfirmationIsPresented = true
    }
}
