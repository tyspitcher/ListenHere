// Downsamples an app-owned local photo file for SwiftUI presentation without network loading.

import ImageIO
import SwiftUI
import UIKit

struct ManagedPhotoImageView: View {
    private static let imageCache = NSCache<NSString, UIImage>()

    @State private var image: UIImage?
    @State private var didFinishLoading = false
    @State private var activeLoadIdentity: String?
    @State private var loadTask: Task<Void, Never>?
    let photoURL: URL?
    var contentMode: ContentMode = .fit
    var maximumPixelSize = 1_800

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .clipShape(.rect(cornerRadius: 16))
                    .accessibilityHidden(true)
            } else if photoURL != nil && didFinishLoading == false {
                ProgressView("Loading Photo")
            } else {
                ContentUnavailableView(
                    "Photo Unavailable",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text("This photo could not be loaded from private storage.")
                )
            }
        }
        .onAppear(perform: startLoadingIfNeeded)
        .onChange(of: photoIdentity) {
            startLoadingIfNeeded()
        }
    }

    private var photoIdentity: String? {
        photoURL.map {
            "\($0.standardizedFileURL.path(percentEncoded: false))#\(maximumPixelSize)"
        }
    }

    private func startLoadingIfNeeded() {
        guard activeLoadIdentity != photoIdentity else { return }
        activeLoadIdentity = photoIdentity
        loadTask?.cancel()

        guard let photoURL else {
            image = nil
            didFinishLoading = true
            return
        }

        let cacheKey = photoIdentity.map(NSString.init) ?? ""
        if let cachedImage = Self.imageCache.object(forKey: cacheKey) {
            image = cachedImage
            didFinishLoading = true
            return
        }

        image = nil
        didFinishLoading = false
        loadTask = Task {
            // Form can temporarily remove and reinsert rows while laying out. This explicitly owned
            // task is not tied to that row-disappearance event, so a valid image load can finish.
            let decodedImage: UIImage? = await Task.detached(
                priority: .userInitiated
            ) { () -> UIImage? in
                autoreleasepool {
                    Self.downsampledImage(
                        at: photoURL,
                        maximumPixelSize: maximumPixelSize
                    )
                }
            }.value
            guard Task.isCancelled == false,
                  activeLoadIdentity == cacheKey as String else {
                return
            }

            if let decodedImage {
                Self.imageCache.setObject(decodedImage, forKey: cacheKey)
                image = decodedImage
            }
            didFinishLoading = true
            loadTask = nil
        }
    }

    nonisolated private static func downsampledImage(
        at url: URL,
        maximumPixelSize: Int
    ) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: image)
    }
}
