// Reads photo dimensions without decoding the image on the main actor.

import Foundation
import ImageIO

enum ManagedPhotoAspectRatio {
    static func isLandscape(_ photoURL: URL?) async -> Bool {
        guard let photoURL else { return false }

        return await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(photoURL as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
                  let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
                return false
            }
            return width > height
        }.value
    }
}
