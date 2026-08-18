import Foundation
import SwiftData

@Model
final class PhotoEditRecipe {
    var id: UUID = UUID()
    var schemaVersion: Int = 1
    var filterIdentifier: String?
    var filterIntensity: Double = 1
    var cropOriginX: Double = 0
    var cropOriginY: Double = 0
    var cropWidth: Double = 1
    var cropHeight: Double = 1
    var rotationDegrees: Double = 0
    var memory: Memory?

    init(
        id: UUID = UUID(),
        filterIdentifier: String? = nil,
        filterIntensity: Double = 1,
        cropOriginX: Double = 0,
        cropOriginY: Double = 0,
        cropWidth: Double = 1,
        cropHeight: Double = 1,
        rotationDegrees: Double = 0
    ) {
        self.id = id
        self.filterIdentifier = filterIdentifier
        self.filterIntensity = filterIntensity
        self.cropOriginX = cropOriginX
        self.cropOriginY = cropOriginY
        self.cropWidth = cropWidth
        self.cropHeight = cropHeight
        self.rotationDegrees = rotationDegrees
    }
}
