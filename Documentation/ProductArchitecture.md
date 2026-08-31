# ListenHere Product and Architecture Map

This is the focused reference for navigation, feature ownership, model relationships, and
canonical filenames. Agents should read `AGENTS.md` first, then this file only when the task
touches one of these areas. Keep this map current as features land.

For the product promise, audience, capstone constraints, privacy position, and essential
framework learning goals, read `Documentation/ProductBrief.md`.

For visible styling, component behavior, theming, or Figma references, read
`Documentation/DesignSystem.md` rather than inferring visual rules from screenshots.

## Confirmed Product Decisions

- ListenHere takes interaction cues from Apple Journal and Apple Photos while keeping its
  own warm, tactile visual identity and its photo-plus-ambient-sound purpose.
- **All Memories** shows entries across every journal.
- **All Memories** is the initial and fallback root. Later launches restore the last valid
  stable browsing path regardless of journal count.
- `MemoryListView` is the journal-detail view. It displays entries for one selected journal.
  Do not create a second `JournalDetailView` for the same responsibility.
- Creating a memory from **All Memories** assigns it to the default journal automatically.
- The first journal created becomes the default journal. The user can choose a different
  default journal in Settings.
- A memory's ellipsis menu opens a journal-assignment sheet.
- Journal assignment supports both moving a memory to a different journal and selecting
  multiple journals.
- Before deleting a journal that contains memories, offer **Delete Journal Only** or **Delete
  Journal & Memories**. Journal-only deletion requires a second sheet where another active
  journal is selected as the destination before the operation can proceed.
- Deleting a journal or memory is initially reversible. Recently Deleted retains its record,
  managed-media references, and journal relationships so it can be restored.
- Recently Deleted retains items for 30 days. Expired items are purged opportunistically at
  app launch and when Recently Deleted opens.
- The ellipsis action for a recently deleted item presents Recover and Delete Permanently.
  A recovered memory returns to any active original journals; if none remain, it is assigned
  to the protected system **Unassigned** journal.
- Places are a way to browse memories; location does not own a memory.
- Audio never autoplays. Playback always follows a deliberate user action.
- Restore the last valid stable browsing path. If a referenced memory or journal no longer
  exists, fall back to All Memories. Never restore transient capture, edit, permission, sheet,
  or confirmation state.

## Primary Navigation

```text
App shell
|-- All Memories (initial and fallback root)
|   |-- Memory Detail
|   |   |-- Journal Assignment sheet (ellipsis menu)
|   |   |-- Edit Memory
|   |   `-- Share Memory
|   `-- New Memory composer sheet
|       |-- Add Photo popover
|       |   |-- Take Photo (full-screen system camera)
|       |   `-- Choose from Library
|       |-- Add Sound popover
|       |   |-- Record Sound (in-place recording)
|       |   `-- Choose Audio File from Files
|       `-- In-place media preview, metadata, and Save
`-- Library / Memory Atlas
    |-- Journals
    |   `-- MemoryListView (journal detail)
    |       `-- Memory Detail
    |-- Places
    |   `-- Memories at the selected place
    |       `-- Memory Detail
    `-- Recently Deleted
        |-- Restore Journal or Memory
        `-- Permanently Delete Journal or Memory
```

Creation may also be offered from a journal's `MemoryListView`. In that case, the selected
journal is the initial assignment. A person can still change or add assignments through the
journal-assignment sheet.

## Presentation Rules

- Prefer native Apple controls, navigation bars, toolbars, menus, sheets, search, and system
  pickers over custom equivalents shown in the Figma exports.
- Use `NavigationStack` with value-based destinations for pushed browsing routes.
- Use a sheet for journal assignment and other short selection tasks.
- Use full-screen presentation for camera capture and immersive media editing. Active audio
  recording stays in the New Memory composer.
- The composer has no internal route or review destination. Keep its media, recording,
  cancellation, retry, and draft-recovery state explicit and testable.
- Reuse memory-card and memory-row components between All Memories and journal detail, but
  keep the two screen responsibilities explicit.
- Pushing Memory Detail and navigating back must preserve the source list position. Track All
  Memories independently from each journal so returning from one memory does not reset another
  list. This position is session-scoped UI state rather than durable navigation restoration.

## Domain Relationships

The journal rule requires a many-to-many relationship:

```text
Journal  <---- many-to-many ---->  Memory
```

Implementation requirements:

- `Memory` must support membership in one or more journals.
- `Journal` must expose its assigned memories.
- The app must identify one default journal or provide a deterministic fallback.
- The first journal created is the initial default. Changing the default must leave exactly
  one default journal when journals exist.
- Saving from All Memories must resolve and assign that default journal atomically with the
  new memory.
- Changing journal assignments must not duplicate the memory or its media files.
- Journal deletion is an explicit two-choice operation. **Delete Journal Only** moves every
  contained memory to a selected active destination journal while preserving other active
  memberships and the deleted source relationship. **Delete Journal & Memories** moves every
  contained memory to Recently Deleted along with the journal; this also removes shared
  memories from active views in their other journals and must say so clearly.
- A journal cannot be its own move destination, and Unassigned is not shown as a manual
  destination. When no other active journal exists, the move sheet explains that another
  journal must be created; destructive journal-and-memory deletion remains available from the
  first confirmation.
- If the deleted journal was the default, the selected move destination becomes the new
  default atomically. Otherwise, the existing default is preserved.
- Soft deletion retains relationships so restoration can recover journal membership.
  Permanent deletion and media-file cleanup happen only through an explicit purge operation.

## Feature and File Locator

The project is currently at the template/placeholder stage. Statuses below prevent an agent
from mistaking empty files for implemented features.

| Product responsibility | Canonical file or feature | Current status |
| --- | --- | --- |
| App composition and launch | `ListenHere/App/ListenHereApp.swift` | Owns AppContainer in state, injects it at the environment boundary, and wires schema, maintenance, and live repositories |
| App shell and root navigation | `ListenHere/App/ContentView.swift` | Reads AppContainer from the environment, builds feature view models through its factories, and hosts NavigationStack with validated path restoration |
| All Memories | `ListenHere/Features/Memories/AllMemoriesView.swift` | Browsing slice implemented |
| Memory-list position restoration | `ListenHere/Features/Memories/AllMemoriesView.swift` and `ListenHere/Features/Journals/MemoryListView.swift` | Pending: returning from Memory Detail should restore the same visible memory and approximate scroll offset independently for All Memories and each journal |
| Library hub | `ListenHere/Features/Library/LibraryView.swift` | Journals, Places, and Recently Deleted routes implemented |
| Journal collection list | `ListenHere/Features/Journals/JournalsView.swift` | Active list and native two-stage deletion flow implemented |
| Journal detail / filtered memories | `ListenHere/Features/Journals/MemoryListView.swift` | Read-only filtered memories implemented |
| Places map | `ListenHere/Features/Places/PlacesView.swift` | Empty state implemented; MapKit browsing pending |
| Memory detail | `ListenHere/Features/Memories/MemoryDetailView.swift` | Displays managed photos and deliberate local audio playback with elapsed time, and presents saved-memory editing; sharing remains pending |
| Create Memory composer | `ListenHere/Features/Capture/CaptureComposerSheet.swift` | One large sheet owns source popovers, in-place media previews, optional metadata, pinned Save, recording presentation, cancellation, and cleanup recovery; there is no capture navigation route |
| Photo Library picker adapter | `ListenHere/Features/Capture/PhotoLibraryPicker.swift` | Native `PhotosPicker` loads the selected photo while its access is valid, then hands bytes to the capture flow; it stores no Photos reference |
| Camera adapter | `ListenHere/Features/Capture/SystemCameraPicker.swift` | Native `UIImagePickerController` camera runs full screen, returns captured bytes to managed storage, and never writes into the user's Photos library |
| Audio file picker | `ListenHere/Features/Capture/CaptureComposerSheet.swift` | Native `fileImporter` reads a security-scoped audio URL and copies bytes into managed media; no external URL is persisted |
| Capture state and persistence | `ListenHere/Features/Capture/CaptureViewModel.swift` | `MemoryDraft` metadata, managed-media ownership, import, cleanup, Save eligibility, and repository transfer are implemented without presentation routing |
| Audio recording | `ListenHere/Features/Capture/VoiceRecordingViewModel.swift` and `ListenHere/Features/Capture/AVFoundationAudioRecordingService.swift` | In-place recording exposes elapsed time and normalized levels, stops manually or after five minutes, and preserves valid partial clips on interruption or backgrounding |
| Composer media preview | `ListenHere/Features/Capture/CaptureMediaPreviewViewModel.swift` | Owns deliberate playback and asynchronous waveform loading for recorded or imported sound |
| Waveform analysis | `ListenHere/Features/Capture/AVFoundationAudioWaveformAnalyzer.swift` | Decodes and downsamples managed audio off the main actor; playback remains available if analysis fails |
| Journal assignment sheet | `ListenHere/Features/Journals/JournalAssignmentSheet.swift` | Native staged multi-selection is integrated into saved-memory editing; the memory ellipsis shortcut remains pending |
| Recently Deleted | `ListenHere/Features/RecentlyDeleted/RecentlyDeletedView.swift` | Implemented and linked from Library |
| Memory editing | `ListenHere/Features/Memories/MemoryEditorSheet.swift` and `MemoryEditSessionViewModel.swift` | Photo/sound replacement or removal, metadata/date changes, and one-or-more journal assignments are implemented. Location-source selection and manual MapKit pin placement remain pending; the editor will choose one canonical memory location from optional photo metadata, sound-capture device location, or a manual pin |
| Video export and sharing | `Features/Sharing/` | Missing |
| Settings | `Features/Settings/SettingsView.swift` | Missing |
| Memory model | `ListenHere/Domain/Models/Memory.swift` | Implemented with metadata, soft deletion, and journals |
| Journal model | `ListenHere/Domain/Models/Journal.swift` | Implemented with default state, soft deletion, and memories |
| Versioned SwiftData schema | `ListenHere/Data/Persistence/ListenHereSchema.swift` | Implemented as schema V1 |
| Managed media storage | `ListenHere/Data/FileStorage/LocalManagedMediaStore.swift` | Private, type-specific media import and safe deletion implemented; Photo Library capture uses it |
| Audio playback service | `ListenHere/Features/Memories/AVFoundationAudioPlaybackService.swift` | AVFoundation-backed local playback is isolated behind a testable service for Memory Detail |
| Memory repository | `ListenHere/Data/Repositories/SwiftDataMemoryRepository.swift` | Active queries, validated creation, assignment, and soft deletion implemented |
| Journal repository | `ListenHere/Data/Repositories/SwiftDataJournalRepository.swift` | Atomic destination move, default, and deletion-batch rules implemented |
| Theme boundary | `ListenHere/DesignSystem/AppTheme.swift` | Semantic light/dark theme implemented |
| Preview fixtures | `ListenHere/PreviewSupport/PreviewFixtures.swift` | Deterministic in-memory fixtures implemented |

Paths under `Features/` describe the intended feature-first destination from `AGENTS.md`.
Do not create all missing files speculatively. Create or move a file only as part of a complete
feature change, then update this table with its actual path and status.

UIKit interop is limited to the system camera adapter where SwiftUI has no equivalent. New UI
should remain SwiftUI-first, and any additional UIKit interop must be wrapped narrowly where an
Apple API requires it.

### Managed Media Contract

`ManagedMediaStoring` is the sole boundary for copying imported photo, audio, or future
exported-video bytes into ListenHere's private media directory. It returns a type-specific,
app-controlled relative filename; a `MemoryDraft` and SwiftData model must never retain an
external Photos URL, camera temporary URL, or absolute sandbox path. Capture and import flows
use this contract before creating or updating persistent memory metadata.

`CaptureViewModel` tracks files imported for its in-progress draft. It releases that ownership
only after a successful repository save; explicit cancellation deletes the tracked files first.
Avoid tying cleanup to a generic SwiftUI `onDisappear`, because a nested system picker can cover
the capture UI without ending the flow.

## Open Product Decisions

- Whether a memory is required to remain in at least one journal after manual reassignment.
- Whether place selection opens a filtered list first or can open a single memory directly.
- Whether restoring a journal also restores every memory from the same deletion batch by
  default or asks which items to restore.

Do not silently resolve these decisions in code. Ask for direction when one blocks the scoped
task, and record the answer here and in `AGENTS.md` if it becomes a repository-wide rule.

## Framework Learning Comments

When AVFoundation or MapKit code lands, place concise comments beside service, adapter,
permission, interruption, route-change, camera-position, or selection logic that benefits from
teaching context. Explain what the Apple type is responsible for and why the boundary exists.
Do not comment ordinary syntax, and do not substitute MapKit comments for separate Core
Location authorization explanations.
