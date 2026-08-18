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
|   `-- Create Memory flow
|       |-- Take Photo
|       |-- Choose from Library
|       |-- Record Sound Only
|       |-- Record or Review Sound
|       `-- Review and Save
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
- Use full-screen presentation for camera capture, active audio recording, and immersive
  media editing.
- Keep capture-flow routing explicit so cancel, retry, and draft recovery can be tested.
- Reuse memory-card and memory-row components between All Memories and journal detail, but
  keep the two screen responsibilities explicit.

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
| App composition and launch | `ListenHere/ListenHereApp.swift` | AppContainer, schema, maintenance, and live repositories wired |
| App shell and root navigation | `ListenHere/ContentView.swift` | NavigationStack with validated path restoration |
| All Memories | `ListenHere/Features/Memories/AllMemoriesView.swift` | Browsing slice implemented |
| Library hub | `ListenHere/MemoryAtlasView.swift` | Journals, Places, and Recently Deleted routes implemented |
| Journal collection list | `ListenHere/JournalsView.swift` | Active list and native two-stage deletion flow implemented |
| Journal detail / filtered memories | `ListenHere/MemoryListView.swift` | Read-only filtered memories implemented |
| Places map | `ListenHere/Features/Places/PlacesView.swift` | Empty state implemented; MapKit browsing pending |
| Memory detail | `ListenHere/Features/Memories/MemoryDetailView.swift` | Read-only detail implemented; playback/edit/share pending |
| Capture source selection | `ListenHere/Features/Capture/CaptureSourceSheet.swift` | Native source routing contract implemented; services pending |
| Audio recording | `Features/Recording/AudioRecordingView.swift` | Missing |
| Review before saving | `Features/Capture/MemoryReviewView.swift` | Missing |
| Journal assignment sheet | `Features/Journals/JournalAssignmentView.swift` | Missing |
| Recently Deleted | `ListenHere/Features/RecentlyDeleted/RecentlyDeletedView.swift` | Implemented and linked from Library |
| Memory editing | `Features/MemoryEditor/` | Missing |
| Video export and sharing | `Features/Sharing/` | Missing |
| Settings | `Features/Settings/SettingsView.swift` | Missing |
| Memory model | `ListenHere/Domain/Models/Memory.swift` | Implemented with metadata, soft deletion, and journals |
| Journal model | `ListenHere/Domain/Models/Journal.swift` | Implemented with default state, soft deletion, and memories |
| Versioned SwiftData schema | `ListenHere/Data/Persistence/ListenHereSchema.swift` | Implemented as schema V1 |
| Memory repository | `ListenHere/Data/Repositories/SwiftDataMemoryRepository.swift` | Active queries, validated creation, assignment, and soft deletion implemented |
| Journal repository | `ListenHere/Data/Repositories/SwiftDataJournalRepository.swift` | Atomic destination move, default, and deletion-batch rules implemented |
| Theme boundary | `ListenHere/DesignSystem/AppTheme.swift` | Semantic light/dark theme implemented |
| Preview fixtures | `ListenHere/PreviewSupport/PreviewFixtures.swift` | Deterministic in-memory fixtures implemented |

Paths under `Features/` describe the intended feature-first destination from `AGENTS.md`.
Do not create all missing files speculatively. Create or move a file only as part of a complete
feature change, then update this table with its actual path and status.

The `*ViewController.swift` placeholder files do not establish a UIKit architecture. New UI
should remain SwiftUI-first, and UIKit should be wrapped narrowly only where an Apple API
requires it.

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
