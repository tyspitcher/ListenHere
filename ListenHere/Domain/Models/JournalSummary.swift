// Provides the lightweight value presented by journal lists without exposing SwiftData models to views.

import Foundation

struct JournalSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let memoryCount: Int
    let isDefault: Bool
    let isSystemUnassigned: Bool
}
