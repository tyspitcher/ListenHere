import Foundation
import SwiftData

@Model
final class MemoryPresentationRecipe {
    var id: UUID = UUID()
    var schemaVersion: Int = 1
    var borderStyleIdentifier: String = "instantPhoto"
    var typographyStyleIdentifier: String = "system"
    var memory: Memory?

    init(
        id: UUID = UUID(),
        borderStyleIdentifier: String = "instantPhoto",
        typographyStyleIdentifier: String = "system"
    ) {
        self.id = id
        self.borderStyleIdentifier = borderStyleIdentifier
        self.typographyStyleIdentifier = typographyStyleIdentifier
    }
}
