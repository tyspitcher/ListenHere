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

    @State private var sourcePopoverIsPresented = false
    @State private var removalConfirmationIsPresented = false

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
        .disabled(isEnabled == false)
    }

    private var palette: AppPalette {
        theme.palette(for: colorScheme)
    }

    private var addPhotoButton: some View {
        Button(action: presentSources) {
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
        .popover(isPresented: $sourcePopoverIsPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Photo")
                    .font(.headline)
                    .padding(.bottom, 4)

                Button("Take Photo", systemImage: "camera", action: chooseCamera)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)

                PhotoLibraryPicker(
                    onPhotoDataSelected: importPhoto,
                    onImportFailure: reportImportFailure
                )
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .padding()
            .presentationCompactAdaptation(.sheet)
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

    private func presentSources() {
        sourcePopoverIsPresented = true
    }

    private func chooseCamera() {
        sourcePopoverIsPresented = false
        takePhoto()
    }

    private func presentRemovalConfirmation() {
        removalConfirmationIsPresented = true
    }
}
