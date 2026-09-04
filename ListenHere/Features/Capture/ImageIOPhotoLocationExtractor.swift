// Reads optional GPS metadata from imported photo bytes.

import Foundation
import ImageIO

struct ImageIOPhotoLocationExtractor: PhotoLocationExtracting {
    func locationCandidate(from imageData: Data) -> MemoryLocationCandidate? {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              let rawLatitude = gps[kCGImagePropertyGPSLatitude] as? Double,
              let rawLongitude = gps[kCGImagePropertyGPSLongitude] as? Double else {
            return nil
        }

        let latitude = signed(rawLatitude, reference: gps[kCGImagePropertyGPSLatitudeRef] as? String, negativeReference: "S")
        let longitude = signed(rawLongitude, reference: gps[kCGImagePropertyGPSLongitudeRef] as? String, negativeReference: "W")
        let location = MemoryLocation(latitude: latitude, longitude: longitude, source: .photoMetadata)
        guard location.isValid else { return nil }
        return MemoryLocationCandidate(location: location)
    }

    private func signed(_ value: Double, reference: String?, negativeReference: String) -> Double {
        reference?.uppercased() == negativeReference ? -abs(value) : abs(value)
    }
}
