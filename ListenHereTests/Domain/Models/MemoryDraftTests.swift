import Foundation
import Testing
@testable import ListenHere

struct MemoryDraftTests {
    @Test("A draft requires a photo or an audio recording")
    func requiresMedia() {
        let draft = MemoryDraft(title: "An empty draft")

        #expect(throws: MemoryDraftValidationError.missingMedia) {
            try draft.validate()
        }
    }

    @Test("A sound-only draft is valid")
    func acceptsSoundOnlyMemory() throws {
        let draft = MemoryDraft(
            audioFilename: "audio/rain.m4a",
            audioDurationSeconds: 20
        )

        try draft.validate()
    }

    @Test("Photo edits use a normalized crop rectangle")
    func rejectsCropOutsidePhotoBounds() {
        let draft = MemoryDraft(
            photoFilename: "photos/forest.heic",
            photoEdits: .init(cropOriginX: 0.8, cropWidth: 0.4)
        )

        #expect(throws: MemoryDraftValidationError.invalidPhotoEdits) {
            try draft.validate()
        }
    }

    @Test("Whitespace-only optional text is normalized to nil")
    func normalizesOptionalText() {
        let draft = MemoryDraft(
            title: "  ",
            caption: "\n",
            photoFilename: " photos/park.heic "
        )

        #expect(draft.normalizedTitle == nil)
        #expect(draft.normalizedCaption == nil)
        #expect(draft.normalizedPhotoFilename == "photos/park.heic")
    }
}
