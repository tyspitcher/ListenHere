// Stores a non-destructive decoration's asset, normalized placement, scale, rotation, and stacking order.

import Foundation
import SwiftData

@Model
final class MemoryDecorationPlacement {
    #Index<MemoryDecorationPlacement>([\.zIndex])

    var id: UUID = UUID()
    var assetIdentifier: String = ""
    var normalizedX: Double = 0.5
    var normalizedY: Double = 0.5
    var scale: Double = 1
    var rotationDegrees: Double = 0
    var zIndex: Int = 0
    var memory: Memory?

    init(
        id: UUID = UUID(),
        assetIdentifier: String,
        normalizedX: Double = 0.5,
        normalizedY: Double = 0.5,
        scale: Double = 1,
        rotationDegrees: Double = 0,
        zIndex: Int = 0
    ) {
        self.id = id
        self.assetIdentifier = assetIdentifier
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.zIndex = zIndex
    }
}
