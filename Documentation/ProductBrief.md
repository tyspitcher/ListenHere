# ListenHere Product Brief

This brief preserves durable intent from the original capstone pitch without treating every
early idea as a current requirement. `AGENTS.md`, `ProductArchitecture.md`, and
`DesignSystem.md` take precedence when a later confirmed decision differs from the pitch.

## Product Promise

**ListenHere: Immersive Sound Postcards** is a private memory journal built around a simple
idea: a photo recalls what a moment looked like, while ambient sound helps recall how it felt.

A person can pair a photo with a short ambient recording, optionally add a title or caption,
retain meaningful date and place context, revisit the result privately, and deliberately
export it as a shareable video postcard. Sound-only capture is also part of the product
direction.

Examples include waves, frogs at night, a child's laughter, music, or the background sound of
an ordinary afternoon. The language and design must support everyday life as naturally as
travel.

## Audience and Differentiation

- Primary audience: people who keep personal memories or journals
- Secondary audience: travelers and people who enjoy nature and ambient sound
- Differentiator: the photo-and-sound pairing is the keepsake, rather than audio being a minor
  attachment to a text entry
- Privacy promise: local and private by default, with no account, public profile, or social
  feed required for the core experience
- Sharing is explicit and user initiated through an exported postcard and the system share
  sheet

## Capstone Success Criteria

This is a personal capstone for an iOS developer program and is intended to become an
App Store-submittable portfolio project. The implementation should demonstrate:

- A distinctive product rather than a clone
- SwiftUI and Human Interface Guidelines-aligned interaction
- Substantial use of Apple frameworks beyond basic UI
- Accessibility, permission handling, and a polished end-to-end experience
- Reliable capture, persistence, playback, and browsing before optional customization

The original plan was time-boxed to roughly eight weeks and prioritized prototyping the
highest-risk integrations early: audio, camera and photo selection, video export, location,
and private cloud persistence. Treat that schedule as historical planning context, not a
current calendar commitment.

## Essential Framework Learning Goals

### AVFoundation

AVFoundation provides the app's defining media behavior: configuring an audio session,
recording short ambient clips, exposing metering values for a waveform, playing recordings,
handling interruptions and route changes, and composing a still image plus audio into a short
shareable video.

Likely Apple types include `AVAudioSession`, `AVAudioRecorder`, `AVAudioPlayer`,
`AVMutableComposition`, and `AVAssetExportSession`. Concrete AVFoundation work belongs behind
narrow recording, playback, and export protocols so view models express user intent and can
be tested without a microphone, speaker route, or export session.

Add short educational comments directly beside AVFoundation service and lifecycle code when
it is implemented, especially around audio-session ownership, interruptions, and route changes.

### MapKit and Core Location

MapKit provides the Places experience: displaying memories geographically, managing map
camera and selection, presenting annotations or clusters, and connecting a selected place to
a memory preview. Core Location is the separate framework responsible for device location
and authorization.

Likely types include SwiftUI's `Map`, `MapCameraPosition`, map annotations or clustering
support, and `CLLocationManager` where live capture location is required. Location access must
remain optional; denial must not prevent memory creation. Framework-specific work belongs
behind a location service or focused map adapter so permissions and live callbacks do not
leak into SwiftUI views.

Add short educational comments beside MapKit and Core Location boundaries when implemented,
clearly separating map rendering and selection from device-location authorization.

### Supporting Frameworks

- PhotosUI and Photos: choose an existing image and use available capture-date or location
  metadata as editable starting values
- SwiftData: persist memory metadata, journal relationships, and managed-media references
- Core Image: optional non-destructive photo filters after the core experience is stable
- CloudKit: future private synchronization after local-first behavior is reliable
- StoreKit: an early pitch explored a free-memory limit and one-time unlock, but monetization
  is not a current MVP commitment

## Experience References

- Apple Journal: quick creation, restrained entry timeline, default-journal behavior, and
  familiar entry management
- Apple Photos: media-first presentation and quiet controls
- Apple Maps: map pins, selection, and preview cards for Places
- Apple Music: approachable playback and prominent artwork
- Day One: elegant journal presentation and strong typography
- Procreate and Adobe Fresco: inspiration only for a small, curated set of creative controls

Apple-native navigation, controls, permissions, and presentation conventions take priority
over custom styling from early mockups. Brand expression should remain centralized and
themeable as described in `DesignSystem.md`.

## Scope Guardrails

Core capstone work centers on capture, short recording, playback, persistence, memory and
journal browsing, Places, and shareable video export. Insights, streaks, audio trimming,
filters, stamps, stickers, crossfade looping, advanced customization, and monetization remain
later ideas unless explicitly promoted into scope.

## Source

Original concept and planning deck:
`/Users/tysonpitcher/Developer/iOSDevelopmentProjects/Course5/ListenHere Capstone Pitch.pages`
