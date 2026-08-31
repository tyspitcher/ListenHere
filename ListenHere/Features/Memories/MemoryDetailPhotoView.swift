// Displays a memory's preview asset or app-managed photo without performing file-system work in SwiftUI.

import SwiftUI

struct MemoryDetailPhotoView: View {
    let thumbnail: MemorySummary.Thumbnail?
    let photoURL: URL?

    var body: some View {
        switch thumbnail {
        case .previewAsset(let assetName):
            Image(assetName)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityHidden(true)
        case .managedFile:
            ManagedPhotoImageView(
                photoURL: photoURL,
                contentMode: .fit,
                maximumPixelSize: 2_400
            )
            .frame(maxWidth: .infinity)
        case nil:
            EmptyView()
        }
    }
}
