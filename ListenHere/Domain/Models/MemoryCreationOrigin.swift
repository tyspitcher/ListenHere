// Identifies where a new memory was created so repository assignment rules can be applied consistently.

import Foundation

enum MemoryCreationOrigin: Equatable, Sendable {
    case allMemories
    case journal(UUID)
}
