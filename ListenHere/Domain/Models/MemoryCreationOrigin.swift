import Foundation

enum MemoryCreationOrigin: Equatable, Sendable {
    case allMemories
    case journal(UUID)
}
