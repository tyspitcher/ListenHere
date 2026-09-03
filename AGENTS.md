# ListenHere Agent Guide

This file is the shared operating context for agents working in this repository. Read it
before planning, editing, reviewing, testing, or committing code. Keep it current when an
architectural or product decision changes.

## Project Snapshot

- Product name: **ListenHere**
- Tagline: **Hear Here**
- Platform: iPhone and iPad
- UI: SwiftUI
- Architecture: MVVM with protocol-based dependency injection
- Persistence: SwiftData for metadata; managed files for photo, audio, and exported video
- Current deployment target: iOS 27.0
- Current Swift language setting: Swift 5
- Bundle identifier: `com.tysonpitcher.ListenHere`
- Project: `ListenHere.xcodeproj`
- Scheme: `ListenHere`
- Context: personal iOS developer-program capstone intended for App Store submission and
  portfolio use

The project is at an early feature stage. The template `Item` model and CRUD interface have
been removed. All Memories is the app shell, and the domain, repository, preview, theme,
Recently Deleted, managed-media, and single-sheet capture composer foundations are in place.

## Canonical Project References

- Read this file first for repository-wide rules and durable product decisions.
- Read [`Documentation/ProductBrief.md`](Documentation/ProductBrief.md) when a task affects
  the product promise, audience, capstone scope, privacy position, or framework learning goals.
- Read [`Documentation/ProductArchitecture.md`](Documentation/ProductArchitecture.md)
  when a task affects navigation, feature boundaries, data relationships, or view naming.
- Read [`Documentation/DesignSystem.md`](Documentation/DesignSystem.md) when a task creates
  or changes visible UI, interaction behavior, theming, colors, backgrounds, or components.
- Read only the feature files named by that map and the files directly involved in the
  requested change; do not scan the entire repository by default.
- Update the map in the same change whenever a route, feature owner, model relationship,
  or canonical filename changes.

## Product Intent

ListenHere is a private, immersive memory journal. Photos capture how a moment looked;
ambient sound captures how it felt.

A memory can contain:

- One photo, with a sound-only memory supported
- One ambient recording
- An optional title and caption
- An editable date and location
- One or more journal assignments
- Non-destructive visual styling and audio edits

Core behavior and terminology:

- Use **All Memories**, showing recent memories across every journal, as the initial and
  fallback root. On later launches, restore the last valid stable browsing path.
- A **Library** hub leads to **Journals** and **Places**.
- Journals organize memories into collections such as family, everyday moments, or a trip.
- `MemoryListView` is the journal-detail screen. It shows the memories assigned to one
  selected journal; do not create a separate `JournalDetailView` unless this decision is
  deliberately revisited.
- Never restore transient capture, edit, permission, sheet, or confirmation state. If a saved
  memory or journal destination no longer exists, return to **All Memories**.
- A memory created from **All Memories** is assigned automatically to the default journal.
- The first journal created becomes the default. A different default can be selected later
  in Settings.
- The memory ellipsis menu presents journal assignment in a sheet. From there, a person can
  move the memory to a different journal or assign it to multiple journals.
- Journal membership is therefore many-to-many: a memory may belong to one or more journals,
  and a journal may contain many memories.
- Deleting a non-empty journal follows Apple Journal's two-stage pattern. First present
  **Delete Journal Only**, **Delete Journal & Memories**, and **Cancel**. Choosing journal-only
  must then present a destination-journal picker before anything is deleted.
- Moving memories during journal-only deletion adds the selected active journal assignment,
  preserves any other active journal assignments, and retains the deleted source relationship
  for recovery. If the deleted journal was the default, the selected destination becomes the
  new default in the same transaction.
- **Delete Journal & Memories** moves the journal and every contained memory to Recently
  Deleted in one batch. If that includes memories shared with other journals, say so clearly.
- Journal and memory deletion is soft by default. Retain deleted records, managed-media
  references, relationships, deletion time, and deletion-batch identity in **Recently Deleted**
  so the user can restore them. Permanently delete metadata and media only through an explicit
  purge operation or after 30 days.
- Check for expired Recently Deleted items at app launch and whenever the Recently Deleted
  view loads. iOS does not guarantee execution at the exact expiration moment.
- An item's ellipsis action in Recently Deleted presents **Recover** and **Delete Permanently**.
  Recovery restores active journal assignments. If none of the original journals remain
  active, assign the memory to the protected system **Unassigned** journal.
- Create a memory in one large modal composer that previews photo and sound in place beside
  optional title and description fields. Save remains visible and is enabled only after at
  least one medium has been added; metadata alone is not a savable memory.
- Support **Take Photo**, **Choose from Library**, **Voice Recording**, and **Choose Audio File**
  for sound-only memories. Voice Recording is an in-app AVFoundation flow; do not route the
  user to Apple's separate Voice Memos app. Files selections must be copied into managed media
  storage while the security-scoped URL is available.
- Present photo and sound source choices from adaptive popovers in the composer. Keep camera
  capture full screen through the system camera, while photo-library and Files selection use
  their native pickers. Active recording remains inside the sound tile in the composer.
- When permission is granted, use capture location and available photo metadata as helpful
  starting values. Location remains optional and editable, and denial must not block capture.
- Preserve distinct location candidates when photo metadata and the device location captured
  during sound recording disagree. Memory editing must let the person choose either candidate
  or place a pin manually on a map; the selected value becomes the memory's single canonical
  location. Imported audio may not provide location metadata, so absence is expected and must
  not block editing.
- Show elapsed recording time and a live waveform in the sound tile. Recording may be stopped
  manually at any time and automatically stops after five minutes, preserving the partial clip.
- Audio never autoplays. The user deliberately presses Play.
- A memory can be exported as a short video and shared through the system share sheet.
- Vertical 9:16 is the default export for Reels and Shorts; square 1:1 is optional.
- Local storage is foundational. Private iCloud sync is planned.
- The product is not a social network and must not depend on user-generated community content.

MVP priority, highest first:

1. Reliable memory capture, persistence, playback, and browsing
2. Borders and typography
3. Shareable video export
4. Map browsing
5. iCloud sync
6. Insights and entry streaks
7. Audio trimming
8. Photo filters
9. Stamps and stickers
10. Crossfade looping

StoreKit, advanced stickers, and crossfade looping are post-capstone unless explicitly
promoted into scope.

## Learning Context

AVFoundation and MapKit are essential learning goals for this capstone, not incidental
dependencies. Whenever code first introduces or meaningfully changes either framework, add
brief educational comments beside the important framework boundary covering:

- What responsibility the framework performs in that change
- The principal Apple types involved
- Why the code lives behind its service or protocol boundary
- Any permission, interruption, route, or lifecycle behavior that matters

Comments should explain intent, framework responsibility, or easy-to-miss lifecycle behavior;
they must not narrate ordinary Swift syntax. Distinguish MapKit, which renders and manages map
interaction, from Core Location, which provides device location and authorization. Do not
repeat this material in the handoff unless it describes a remaining risk or verification need.

## Brand and Experience

The source brand notes are in `ListenHere/BrandAttributes.md`.

Primary attributes:

- Polished
- Immersive
- Warm
- Delightful
- Trustworthy

Supporting qualities include private, secure, nostalgic, thoughtful, intimate, calming,
expressive, clean, elegant, reliable, and easy to use.

Visual direction:

- Warm cream, heavyweight-paper background with restrained texture in light mode
- White instant-photo edges with a slightly deeper lower border
- Soft, realistic shadows that create subtle physical depth
- SF Pro and SF Symbols for controls, metadata, and body text
- Handwritten typography only as a readable accent
- A jewel-tone default palette: Deep Sapphire `#1D5C8A` as primary, Muted Emerald
  `#20755C` as secondary, and Warm Garnet `#94384B` as tertiary
- Content-first presentation inspired by Apple Journal and Apple Photos
- Apple Maps-inspired interaction for Places

The Figma exports are flow and information-hierarchy references, not pixel-perfect visual
specifications. Prefer native Apple navigation, toolbars, menus, sheets, buttons, pickers,
search, camera/photo interfaces, and platform behaviors whenever they meet the product need.
Apple-style familiarity and HIG compliance take precedence over custom Figma chrome.

Keep brand styling centralized and themeable. Feature views must consume semantic theme
values rather than hard-code brand colors, textures, background patterns, shadows, or type
treatments. Preserve a path for future user-selectable themes without requiring feature-view
rewrites. See `Documentation/DesignSystem.md` for the source hierarchy and implementation
constraints.

Avoid torn-paper edges, arbitrary postage marks, excessive stickers, exaggerated shadows,
visual clutter, and travel-only language. The app must feel appropriate for ordinary life,
family moments, nature, music, and travel.

## Architecture: MVVM + SOLID

MVVM is the presentation architecture. Apply it consistently without creating unnecessary
types for trivial views.

### Dependency Direction

```text
View -> ViewModel -> Domain protocol/use case -> Repository or service
                                  ^
                                  |
                         Live implementation
```

- Views depend on view models, never directly on repositories or services.
- View models depend on narrow protocols, not concrete AVFoundation, Photos, MapKit,
  CloudKit, or SwiftData implementations.
- Domain models and business rules do not depend on SwiftUI.
- Live dependencies are assembled at the app composition root.
- Framework-specific types should not leak across boundaries when a small domain type works.

### View Responsibilities

A SwiftUI view should:

- Render observable state
- Forward user intent to the view model
- Own only transient presentation details such as focus, scroll position, or a local animation
- Use small reusable subviews when a section has an independent visual responsibility

A view should not:

- Fetch or persist models
- Manage AVAudioSession, camera capture, file I/O, export sessions, or CloudKit
- Contain business rules or expensive data transformations in `body`
- Construct live service graphs
- Use multiple booleans for mutually exclusive screen states

### ViewModel Responsibilities

Use `@MainActor` and the Observation framework for new view models:

```swift
@MainActor
@Observable
final class MemoriesViewModel {
    private(set) var state = MemoriesState()

    private let repository: MemoryRepository

    init(repository: MemoryRepository) {
        self.repository = repository
    }
}
```

A view model should:

- Own presentation state and user-intent methods
- Translate domain data into stable view data
- Coordinate asynchronous work through injected protocols
- Expose mutations through intent methods rather than writable public properties
- Model loading, permission, recording, playback, exporting, and failure states explicitly
- Own and cancel tasks when a newer user action makes prior work stale
- Map technical failures into concise, actionable presentation errors

Avoid god view models. Split a flow when a view model starts owning unrelated capture,
editing, browsing, and export responsibilities.

`CaptureViewModel` is intentionally limited to the temporary `MemoryDraft`, managed-media
handoff, cleanup, and repository creation. Keep PhotosUI and UIKit camera presentation in
narrow adapters, and keep recording, waveform analysis, playback, and editing in their own
focused services or view models rather than expanding `CaptureViewModel` into a media pipeline.

Likely feature view models include:

- `AllMemoriesViewModel`
- `LibraryViewModel`
- `JournalsViewModel`
- `JournalDetailViewModel`
- `PlacesViewModel`
- `CaptureViewModel`
- `AudioRecordingViewModel`
- `MemoryReviewViewModel`
- `MemoryDetailViewModel`
- `PhotoEditorViewModel`
- `AudioTrimViewModel`
- `ShareMemoryViewModel`
- `SettingsViewModel`

These are expected boundaries, not a request to create empty files before they are needed.

### State Modeling

Prefer enums and small state structures over overlapping booleans:

```swift
enum RecordingState: Equatable {
    case idle
    case requestingPermission
    case recording(elapsed: Duration, levels: [Double])
    case finalizing
    case failed(RecordingError)
}
```

Keep one source of truth. Do not duplicate the same durable state in a view, view model,
and service.

### Dependency Injection

- Use constructor injection for required dependencies.
- Define small capability-focused protocols at the boundary that consumes them.
- Build live implementations in an `AppContainer` or feature assembly.
- Supply fakes or stubs in tests and previews.
- Avoid global mutable state and service singletons.
- Environment injection is acceptable at the app boundary, but dependencies should remain
  explicit when constructing a view model.

### SOLID Expectations

- **Single Responsibility:** a type has one reason to change. Recording, playback, file
  storage, metadata persistence, and video export are separate responsibilities.
- **Open/Closed:** extend behavior through composition and protocol implementations instead
  of growing central switch statements or subclass trees.
- **Liskov Substitution:** every live, preview, and test implementation must honor the same
  protocol behavior, errors, and cancellation semantics.
- **Interface Segregation:** prefer focused protocols such as `AudioRecording`,
  `AudioPlaying`, and `VideoExporting` over one large `MediaService`.
- **Dependency Inversion:** feature logic depends on domain-facing protocols; Apple
  frameworks remain implementation details.

Do not create a protocol for every concrete type. Introduce one when it establishes a real
side-effect boundary, supports multiple implementations, or makes important logic testable.

## Suggested Project Organization

Grow toward feature-first organization:

```text
ListenHere/
  App/
    ListenHereApp.swift
    AppContainer.swift
    AppRouter.swift
    ContentView.swift
    NavigationStateStore.swift
  Features/
    Memories/
      Views/
      ViewModels/
      ViewData/
    Library/
    Journals/
    Places/
    Capture/
    Recording/
    MemoryEditor/
    Sharing/
    Settings/
  Domain/
    Models/
    Protocols/
    UseCases/
  Data/
    Persistence/
    Repositories/
    FileStorage/
  Services/
    Camera/
    Audio/
    Location/
    ImageEditing/
    VideoExport/
    CloudSync/
  DesignSystem/
    Components/
    Styles/
    Assets/
  Utilities/
```

Create folders when the feature exists. Do not scaffold the entire tree prematurely.
Prefer one primary type per file and name the file after that type.

## Navigation

- Use `NavigationStack` and value-based destinations for SwiftUI navigation.
- Use **All Memories** as the initial and fallback launch destination and keep it distinct
  from `MemoryListView`, which is scoped to one journal. Later launches restore the last valid
  stable browsing path.
- When a person opens Memory Detail from All Memories or a journal and then navigates back,
  restore that source list to the same visible memory and approximate scroll offset. Keep scroll
  position separately for All Memories and each journal while their browsing stacks remain alive;
  this is transient presentation state and does not need to survive a new app launch.
- Treat the Apple Journal app as the primary interaction reference for the entry list,
  journal switching, new-memory placement, and journal-assignment sheet while preserving
  ListenHere's own visual identity and photo-plus-ambient-sound purpose.
- Use sheets for short selection and editing tasks.
- Use the native confirmation dialog and a destination-selection sheet for journal deletion;
  do not replace this flow with a custom alert replica.
- Present journal assignment from a memory's ellipsis menu as a sheet with multi-selection.
- Use full-screen presentation for camera and immersive media editors. Active recording stays
  visible in the Create Memory composer's sound tile.
- As the number of flows grows, centralize app-level routing in `AppRouter`.
- View models may decide *where* an intent leads; SwiftUI views or the router decide *how*
  it is presented.
- View models must not reference `NavigationController`, `UIViewController`, or other
  presentation APIs.
- The Create Memory composer has no internal navigation route. Keep its presentation state,
  cancellation, and draft recovery explicit and testable.

Use UIKit only where an Apple API lacks an adequate SwiftUI interface. Wrap UIKit narrowly
in a representable or adapter and keep it outside the view model.

## Data and Media Ownership

SwiftData records should store durable metadata, identifiers, relationships, edit recipes,
and relative media references.

- Do not store large photo, audio, or video blobs directly in SwiftData without a measured
  reason.
- Store media in app-managed files and persist stable relative filenames, not absolute
  sandbox paths.
- Copy imported or captured data through `ManagedMediaStoring`; it returns only an
  app-controlled relative filename and prevents temporary or externally owned URLs from
  becoming durable model references.
- A capture session owns newly imported managed files until its repository save succeeds.
  Explicit cancellation must remove those files before dismissal. Do not use a broad view
  `onDisappear` callback for this cleanup: nested system pickers can temporarily cover a view.
  When imported files exist, prevent interactive sheet dismissal and use explicit Cancel so
  cleanup can report a recoverable failure.
- Give every memory a stable UUID.
- Keep original photo and audio files when supporting non-destructive editing.
- Write files atomically where possible.
- Define ownership before deleting or replacing files.
- If a database operation fails after a file write, clean up the orphaned file.
- If a file operation fails, do not leave metadata claiming the media exists.
- Exported videos are derived artifacts and should be reproducible from saved memory data.
- Clean temporary export files after sharing or cancellation.
- Design persistence so later CloudKit sync does not require rewriting presentation code.
- Repository operations should express domain intent, such as `save(memory:)` and
  `deleteMemory(id:)`, rather than exposing raw `ModelContext` to view models.

## Apple Framework Boundaries

Expected frameworks include:

- SwiftUI for interface and navigation
- SwiftData for local metadata persistence
- AVFoundation for ambient recording, metering, playback, interruption and route handling,
  trimming or replacement, and still-image-plus-audio video export
- PhotosUI for selecting library photos
- UIKit interop only where needed for camera capture or system sharing
- MapKit for Places browsing, annotations, selection, and memory previews; Core Location for
  capture coordinates and location authorization
- Core Image for non-destructive photo filters
- CloudKit/SwiftData sync for private iCloud synchronization
- OSLog for privacy-aware diagnostics

Hide these frameworks behind focused services where they perform side effects. Do not add
third-party packages when an Apple framework or a small local abstraction is sufficient.
Any new dependency requires a clear benefit, license review, and explicit approval.

## Concurrency and Lifecycle

- Prefer structured concurrency and `async`/`await`.
- Keep observable view-model mutation on `@MainActor`.
- Use actors for shared mutable media/file state when appropriate.
- Never perform encoding, image processing, waveform analysis, or video export work on the
  main actor.
- Check cancellation in long-running operations.
- Cancel capture, search, playback, and export tasks when their owning flow ends.
- Make service and domain values `Sendable` where they cross concurrency boundaries.
- Avoid `Task.detached` unless isolation and captured values are deliberately designed.
- Handle app backgrounding, interruptions, audio-route changes, and permission changes.
- Do not ignore errors. Cancellation may be silent; real failures need logging and a user
  recovery path.

## Privacy and Security

Privacy is a product feature.

- Keep memories local or in the user's private iCloud account.
- Request camera, microphone, Photos, and location access just in time and explain the
  immediate benefit.
- Support denial and restricted states without trapping the user.
- Share media only after an explicit user action.
- Never log memory titles, captions, precise locations, photos, or audio contents.
- Use privacy annotations with OSLog.
- Never commit credentials, provisioning material, personal recordings, or private test data.
- Store future user-supplied API credentials in Keychain.
- Use synthetic or explicitly licensed sample media in source control and tests.

## Design, HIG, and Accessibility

- Follow Apple Human Interface Guidelines and platform conventions.
- Use native SwiftUI controls and standard navigation behavior by default. Customize only
  where the customization expresses a confirmed ListenHere product or brand requirement.
- Treat the Figma screens as references for content, hierarchy, and flow; do not reproduce
  their custom controls when a standard Apple control provides the same behavior.
- Consume semantic design tokens from one injected app theme. Do not place raw brand colors,
  background textures, or theme-selection branches throughout feature views.
- Keep visual theme choice separate from system light/dark appearance so both can evolve.
- Keep interactive targets at least 44 by 44 points.
- Support Dynamic Type without truncating essential actions.
- Add meaningful VoiceOver labels, values, hints, and grouping.
- Never communicate recording, playback, selection, or failure using sound or color alone.
- Respect Reduce Motion and avoid animations that delay interaction.
- Preserve sufficient contrast over paper textures and photographs.
- Use native controls where they improve familiarity and accessibility.
- Audio must have visible waveform, timer, and playback state.
- Destructive actions require direct labels and confirmation.
- Keep interface copy warm and concise; clarity overrides personality in errors and privacy
  prompts.

## Error Handling and Diagnostics

- Prefer typed domain errors over passing raw framework errors into the UI.
- Provide recovery actions such as Retry, Open Settings, Replace Recording, or Keep Editing.
- Preserve a user's draft whenever an operation can reasonably be retried.
- Use assertions for programmer invariants, not recoverable runtime conditions.
- Avoid force unwraps and `try!`.
- Reserve `fatalError` for truly unrecoverable app-configuration failures.
- Log subsystem and category information without private content.

## Testing Standards

Use Swift Testing for new unit tests unless an existing target or API requires XCTest.

At minimum, test:

- View-model state transitions for success, failure, and cancellation
- Domain mapping and validation
- Repository behavior and media/file cleanup
- Recording duration behavior for 10, 20, and 30 seconds
- Permission denial and later authorization
- Sound-only and photo-plus-sound creation
- Save, edit, move, and delete behavior
- Timeline and journal filtering
- Location-present and location-absent behavior
- Video-export success, cancellation, and failure
- No stale async result overwrites newer state

Testing rules:

- Inject fakes; do not make unit tests depend on microphones, cameras, network, or iCloud.
- Avoid sleep-based async tests. Use controllable continuations, clocks, or fakes.
- Use an in-memory SwiftData container for persistence tests and previews.
- Keep UI tests focused on critical end-to-end flows.
- Test camera, microphone, audio session interruptions, and sharing on physical devices.
- Include VoiceOver, Dynamic Type, Reduce Motion, light/dark appearance, and orientation in
  manual test passes.
- Every bug fix should include a regression test when practical.

## Coding Conventions

- Favor clear names over abbreviations.
- Use access control intentionally; default implementation details to `private`.
- Keep methods small and at one level of abstraction.
- Prefer immutable values and value types for state and view data.
- Use extensions to organize protocol conformance or closely related behavior.
- Avoid dumping unrelated helpers into generic utility files.
- Document why a non-obvious constraint exists; do not narrate obvious syntax.
- Do not introduce speculative abstractions for hypothetical features.
- Keep preview data deterministic and clearly synthetic.
- Remove dead code, placeholder UI, and unused assets as their replacements land.

## Agent Working Agreement

Before editing:

1. Read this file and the files directly relevant to the task.
2. Inspect `git status` and preserve user changes.
3. Identify the issue, acceptance criteria, and current branch.
4. State assumptions if the task leaves a material decision open.
5. Prefer the smallest complete change that satisfies the issue.

While editing:

- Do not modify unrelated files.
- Do not overwrite user-authored work.
- Keep business logic out of SwiftUI views.
- Inject new side-effect dependencies.
- Add or update tests alongside behavior.
- Maintain backward compatibility with the current deployment target.
- Do not silently expand MVP scope.

Before handoff:

1. Build the `ListenHere` scheme.
2. Run relevant unit and UI tests.
3. Review the diff for unrelated changes and private data.
4. Report what changed, what was verified, and any remaining risk.
5. Do not claim physical-device behavior was tested unless it was.

Git rules:

- Work from an issue-specific branch, not directly on `main`.
- Use focused commits with messages such as `feat:`, `fix:`, `test:`, `docs:`, or `refactor:`.
- Never stage unrelated changes.
- Do not rewrite shared history.
- Do not commit, push, merge, tag, or create a release unless explicitly requested.
- Link pull requests to their issue with `Closes #<issue-number>`.

## Architecture Review Checklist

Before accepting a feature or pull request, confirm:

- The view renders state and forwards intent without calling services.
- The view model has one coherent presentation responsibility.
- State is explicit and has one source of truth.
- Dependencies are injected through focused protocols.
- Domain types are not coupled to SwiftUI or UIKit.
- Async work has cancellation and error handling.
- Heavy work stays off the main actor.
- Navigation uses values or a router rather than framework calls in the view model.
- Persistence and media files remain consistent through failure and deletion.
- Unit tests cover success, failure, cancellation, and important mapping.
- UI supports accessibility and privacy requirements.
- The implementation matches current MVP priority and product terminology.
