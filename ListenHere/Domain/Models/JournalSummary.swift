import Foundation

struct JournalSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let memoryCount: Int
    let isDefault: Bool
    let isSystemUnassigned: Bool
}
