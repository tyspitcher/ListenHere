// Defines the SwiftData journal model, memory relationship, default state, and soft deletion lifecycle.

import Foundation
import SwiftData

@Model
final class Journal {
    #Index<Journal>([\.createdAt], [\.deletedAt, \.createdAt])

    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var isDefault: Bool = false
    var isSystemUnassigned: Bool = false
    var wasDefaultBeforeDeletion: Bool = false
    var deletedAt: Date?
    var deletionBatchID: UUID?
    var coverPhotoFilename: String?

    @Relationship(deleteRule: .nullify, inverse: \Memory.journals)
    var memories: [Memory]?

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        isDefault: Bool = false,
        isSystemUnassigned: Bool = false,
        coverPhotoFilename: String? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isDefault = isDefault
        self.isSystemUnassigned = isSystemUnassigned
        self.coverPhotoFilename = coverPhotoFilename
    }

    func add(_ memory: Memory) {
        var updatedMemories = memories ?? []
        guard updatedMemories.contains(where: { $0.id == memory.id }) == false else {
            return
        }

        updatedMemories.append(memory)
        memories = updatedMemories
    }

    func remove(_ memory: Memory) {
        memories = memories?.filter { $0.id != memory.id }
    }

    var isRecentlyDeleted: Bool {
        deletedAt != nil
    }

    func moveToRecentlyDeleted(at date: Date = Date(), batchID: UUID = UUID()) {
        wasDefaultBeforeDeletion = isDefault
        deletedAt = date
        deletionBatchID = batchID
        isDefault = false
        modifiedAt = date
    }

    func restoreFromRecentlyDeleted(at date: Date = Date()) {
        deletedAt = nil
        deletionBatchID = nil
        modifiedAt = date
    }

    func finishRestoration() {
        wasDefaultBeforeDeletion = false
    }
}
