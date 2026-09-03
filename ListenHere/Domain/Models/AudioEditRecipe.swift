// Stores the non-destructive audio trim, looping, and crossfade recipe for a memory.

import Foundation
import SwiftData

@Model
final class AudioEditRecipe {
    var id: UUID = UUID()
    var schemaVersion: Int = 1
    var trimStartSeconds: Double = 0
    var trimEndSeconds: Double?
    var isLoopingEnabled: Bool = false
    var crossfadeDurationSeconds: Double = 0
    var memory: Memory?

    init(
        id: UUID = UUID(),
        trimStartSeconds: Double = 0,
        trimEndSeconds: Double? = nil,
        isLoopingEnabled: Bool = false,
        crossfadeDurationSeconds: Double = 0
    ) {
        self.id = id
        self.trimStartSeconds = trimStartSeconds
        self.trimEndSeconds = trimEndSeconds
        self.isLoopingEnabled = isLoopingEnabled
        self.crossfadeDurationSeconds = crossfadeDurationSeconds
    }
}
