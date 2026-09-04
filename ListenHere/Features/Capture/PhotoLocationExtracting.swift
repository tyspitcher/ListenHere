// Isolates image-metadata parsing so the capture flow never depends directly on ImageIO.

import Foundation

protocol PhotoLocationExtracting: Sendable {
    func locationCandidate(from imageData: Data) -> MemoryLocationCandidate?
}
