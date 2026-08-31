# ListenHere Design System Direction

This is the canonical reference for visible UI, native interaction choices, theming, and the
role of the Figma exports. Read `AGENTS.md` first. Use `Documentation/ProductArchitecture.md`
for navigation and feature ownership.

## Experience Goal

ListenHere should feel polished, seamless, warm, immersive, and trustworthy. A person who is
comfortable with Apple's apps should immediately understand how to navigate, create a memory,
edit it, and share it.

Polish should come from clear hierarchy, excellent spacing, responsive feedback, restrained
motion, strong media presentation, and consistent native behavior—not from replacing familiar
controls with custom replicas.

## Source Priority

When visual references disagree, use this order:

1. Accessibility, privacy, and platform-correct behavior.
2. Apple Human Interface Guidelines and native SwiftUI interaction patterns.
3. Confirmed product behavior in `AGENTS.md` and `Documentation/ProductArchitecture.md`.
4. ListenHere brand attributes in `ListenHere/BrandAttributes.md`.
5. Figma exports for content, hierarchy, screen purpose, and flow inspiration.

The Figma exports are not pixel-perfect implementation requirements. Default Apple buttons,
navigation bars, toolbar items, menus, sheets, confirmation dialogs, search, PhotosUI pickers,
and camera conventions take precedence whenever they satisfy the task. Do not recreate a
system control only to match the mockup's shape or placement.

The broken-image/question-mark placeholders visible in some exports are export artifacts,
not intended UI assets.

## Native-First Interaction Rules

- Use `NavigationStack` and value-based destinations for pushed routes.
- Use toolbar items and `Menu` for contextual actions such as a memory's ellipsis menu.
- Use one large modal sheet for the New Memory composer. Use adaptive popovers for its photo
  and sound source choices, preserving native compact-sheet adaptation on iPhone.
- For a non-empty journal, use a native destructive confirmation with **Delete Journal Only**,
  **Delete Journal & Memories**, and **Cancel**. If journal-only is chosen, follow with a native
  sheet titled **Move Memories** containing a journal picker, the affected count, **Move
  Memories & Delete Journal**, and **Cancel**.
- Use full-screen presentation for camera capture and immersive editing. Keep active recording
  visible in the composer's sound tile with a Stop label, stop icon, elapsed timer, and waveform.
- Use `PhotosPicker` for photo-library selection unless a confirmed requirement needs more.
- Use `searchable()` for journal and place search where it fits the screen.
- Use system alerts and permission prompts. A custom rationale screen may explain the benefit
  immediately before the system prompt, but must not imitate the system permission dialog.
- Use `ContentUnavailableView` for appropriate empty and no-results states.
- Start with standard button styles, materials, list behavior, safe-area handling, and system
  transitions. Add custom treatment only when it communicates a confirmed product role.

## New Memory Composer

- Present Add Photo and Add Sound as large media tiles. Lay them out side by side when space
  permits and stack them at accessibility Dynamic Type sizes.
- Replace a source tile with its media preview after import. Photo uses aspect fill; sound uses
  a waveform, explicit play or pause control, playback progress, and elapsed and total time.
- Put optional Title and Description directly below the media tiles. Pin Save Memory above the
  bottom safe area so media size, scrolling, and the keyboard do not hide it.
- Disable and visually de-emphasize Save until a photo or sound exists. Do not use title or
  description alone to enable it.
- Media trash controls require a native confirmation dialog and a 44-point target. Removing
  one medium preserves the other medium and all metadata.
- Keep Cancel in the toolbar. Confirm leaving whenever media, recording, title, or description
  exists; an untouched composer dismisses immediately.

## Theme Architecture

The UI must be easy to restyle and must leave room for future user-selectable themes.

When the first production screen is implemented, grow a small design system under
`ListenHere/DesignSystem/` rather than scattering constants through feature views. Do not
create empty types before a real screen needs them.

Use these boundaries:

- `AppTheme`: one injected presentation value describing the active visual theme.
- `ThemeID`: a stable, persistable identifier for built-in or future selectable themes.
- Semantic palette roles such as `appBackground`, `surface`, `elevatedSurface`,
  `primaryText`, `secondaryText`, `accent`, `destructive`, and `separator`.
- A centralized background treatment that can switch between system/plain, subtle paper,
  or future patterns without changing feature views.
- Reusable product components only when ListenHere has a recurring visual responsibility,
  such as a memory media card, waveform player, or recording control.

Feature views should ask for semantic roles, not specific colors. Do not persist SwiftUI
`Color` values or branch on a theme name throughout screen code. Persist a stable `ThemeID`
and resolve its concrete palette and background at the app boundary.

System light/dark appearance and ListenHere theme choice are separate concepts. A theme must
provide accessible variants for both appearances. The first implementation should work with
the system appearance even if selectable themes arrive later.

The first theme boundary is implemented in `ListenHere/DesignSystem/AppTheme.swift`. All
Memories consumes its semantic palette through the environment; extend those roles rather
than adding feature-local colors.

### Current Default Theme

The persisted `ThemeID.listenHere` resolves to the current jewel-tone theme. Keep the ID
stable even if its visual recipe evolves so saved preferences remain valid.

- Primary / accent: Deep Sapphire `#1D5C8A`
- Secondary accent: Muted Emerald `#20755C`
- Tertiary accent: Warm Garnet `#94384B`
- Light backdrop: `WatercolorPaper` from the production asset catalog over a warm cream base
- Dark backdrop: a solid deep blue-black surface; the light paper image is intentionally not
  used in dark mode

Dark-mode accents are lightened derivatives of the three jewel colors so controls and symbols
retain sufficient contrast. Feature views consume `accent`, `secondaryAccent`, and
`tertiaryAccent`; they do not reference hex values or asset names.

`AppTheme` owns both palettes and backdrop treatments. Adding a future selectable theme means
adding a stable `ThemeID`, defining one `AppTheme`, and exposing it through `ThemeID.theme`.
The root applies the resolved theme and native control tint once, while `AppBackground`
renders the selected light/dark backdrop centrally.

## Styling Constraints

- Prefer SF Pro and SF Symbols for controls, metadata, and body content.
- Use handwritten typography only as a restrained, readable accent.
- Keep all palette values inside `AppTheme`; do not hard-code the jewel hex values in feature
  views.
- Treat paper grain or other patterns as decorative layers. They must not reduce text or icon
  contrast, interfere with scrolling performance, or be exposed as meaningful VoiceOver
  content.
- Keep shadows soft and purposeful. Do not use elevation to compensate for unclear hierarchy.
- Avoid fixed text sizes and rigid frames that break Dynamic Type or iPad layouts.
- Memory cards fill the available list width in compact horizontal size classes. In regular
  width, center cards at a maximum width of 720 points so photos and metadata remain readable;
  iPad multitasking follows the current environment size class automatically.
- Respect Reduce Motion, Increase Contrast, Differentiate Without Color, and Reduce
  Transparency where the chosen effects are affected.
- Maintain at least 44-by-44-point interaction targets.

## Verification Matrix

Every implemented visual feature should be checked in:

- Light and dark appearance
- At least one large Dynamic Type size
- Increased contrast where relevant
- Reduce Motion and Reduce Transparency where relevant
- iPhone and iPad layouts supported by the target
- VoiceOver reading order and labels
- The default theme plus each user-selectable theme once themes are introduced

## Figma Reference Manifest

The original exports were provided in:

`/Users/tysonpitcher/Desktop/ListenHereScreenshots/`

Durable copies for Product Design workflows are stored under:

`~/.codex/state/plugins/product-design/assets/`

| Reference | Saved asset | Intended use |
| --- | --- | --- |
| All Memories, upper list | `listenhere-figma-all-memories-list-top.png` | Entry-card hierarchy, audio preview, metadata, create entry point |
| All Memories, lower list | `listenhere-figma-all-memories-list-lower.png` | Continued list behavior and persistent create entry point |
| Library hub | `listenhere-figma-library-hub.png` | Journals and Places entry points plus optional summary information |
| Places map | `listenhere-figma-places-map.png` | Map browsing, search, selection, and memory preview concept |
| Journals grid | `listenhere-figma-journals-grid.png` | Searchable journal collection and creation concept |
| Memory detail, hero | `listenhere-figma-memory-detail-hero.png` | Media, playback, title, caption, edit, and share hierarchy |
| Create-memory source sheet | `listenhere-figma-create-memory-source-sheet.png` | Take Photo, Choose from Library, and Voice Recording choices |
| Camera rationale | `listenhere-figma-camera-permission-rationale.png` | Pre-permission explanation concept; do not imitate the system prompt |
| Camera capture | `listenhere-figma-camera-live-capture.png` | Full-screen capture controls and cancellation concept |
| Captured-photo review | `listenhere-figma-camera-photo-review.png` | Retake or accept decision |
| Sound invitation | `listenhere-figma-sound-invitation.png` | Photo-first invitation to add ambient sound |
| Microphone rationale | `listenhere-figma-microphone-permission-rationale.png` | Pre-permission explanation concept; do not imitate the system prompt |
| Active recording | `listenhere-figma-audio-recording-active.png` | Recording state, timer, waveform, cancellation, and Stop |
| Memory review and save | `listenhere-figma-memory-review-save.png` | Review media, add metadata, and save the draft |
| Memory detail metadata | `listenhere-figma-memory-detail-metadata.png` | Date, location, journal assignment, and duration presentation |

Inspect only the references relevant to the current task. Preserve their product intent while
adapting controls, navigation, spacing, and presentation to current Apple platform conventions.

Development-only crops used by SwiftUI previews live in
`ListenHere/Preview Content/Preview Assets.xcassets`. Keep them out of the production asset
catalog and crop only photographic content, never Figma navigation or control chrome.
